// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "hardhat/console.sol";

contract NiftyFlex is ERC721Enumerable, Ownable {
    using SafeMath for uint8;
    using SafeMath for uint256;
    using Strings for string;  

    struct NfxProduct {
        // product id
        uint256 id;
        // product price with $ASh
        uint256 price;
        // product name
        string name;
        // flag for NFT token balance checking
        bool isRequiredNftTokenBalance;
        // Nft token contract address
        address nftTokenContractAddress;    
        // flag is it deleted or not
        bool isDeleted;    
    }

    // mapping for product information
    mapping(uint256 => NfxProduct) public nfxProductData;

    // Contract name
    string private _tokenName = "Nifty-Flex";

    // Contract symbol
    string private _tokenSymbol = "NFX";    

    // product id tracker
    uint256 private _nextProductId;

    // token id tracker
    uint256 private _nextTokenId;

    // payment contract address
    address private _ashContract = 0x09d8AF358636D9BCC9a3e177B66EB30381a4b1a8;  // ZAP address  for test
    // address ashContract_address = 0x09d8AF358636D9BCC9a3e177B66EB30381a4b1a8;  // ASH address  for live

    // base token Uri
    string  private  _baseTokenUri = "https://api.nifty-flex.xyz/metadata/";

    constructor() ERC721(_tokenName, _tokenSymbol) Ownable() {

    }   

    function setBaseTokenUri(string memory _uri) public onlyOwner {
        _baseTokenUri = _uri;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "NiftyFlex#tokenURI: URI query for nonexistent token");
        
        return string(abi.encodePacked(_baseTokenUri, Strings.toString(tokenId)));
    }

    function getProductCount() public view returns (uint256 productCount) {
        return _nextProductId;
    }

    function getProductInfo(uint256 _productId) public view returns (
        uint256 _id,
        uint256 _price,
        string memory _name,
        bool _isRequiredNftTokenBalance,
        address _nftTokenContractAddress,
        bool _isDeleted
    ) {
        NfxProduct memory productInfo = nfxProductData[_productId];
        return (
            productInfo.id,
            productInfo.price,
            productInfo.name,
            productInfo.isRequiredNftTokenBalance,
            productInfo.nftTokenContractAddress,
            productInfo.isDeleted            
        );
    }

    function addProduct(
        string memory _name,
        uint256 _price,
        bool _isRequiredNftTokenBalance,
        address _nftTokenContractAddress
    ) public onlyOwner {
        // check product name
        bytes memory tempProductName = bytes(_name);
        require(tempProductName.length > 0, "NFX#addProduct: product name cannot be empty");

        // check product price
        require(_price > 0, "NFX#addProduct: product price cannot be empty");

        // check product NFT token balance flag
        if(_isRequiredNftTokenBalance) {
            require(_nftTokenContractAddress != address(0x0), "NFX#addProduct:  product nftTokenContractAddress cannot be empty");
        }

        // increase product id
        _nextProductId += 1;
        // _price = _price * 10**18;
        // create a new product information
        NfxProduct memory newNfxProduct = NfxProduct(
            _nextProductId,
            _price.mul(10**18),
            _name,
            _isRequiredNftTokenBalance,
            _nftTokenContractAddress,
            false
        );

        // assign it to mapping
        nfxProductData[_nextProductId] = newNfxProduct;
    }

    function updateProduct(
        uint256 _id,
        string memory _name,
        uint256 _price,
        bool _isRequiredNftTokenBalance,
        address _nftTokenContractAddress
    ) public onlyOwner {

        // check product id
        require(_id > 0 && _id <= _nextProductId, "NFX#addProduct: product id cannot be empty");

        // get product information
        NfxProduct memory productInfo = nfxProductData[_id];
        
        // update product name
        bytes memory tempProductName = bytes(_name);
        if(tempProductName.length > 0) {
            productInfo.name = _name;
        }

        // update product price
        if(_price > 0) {
            productInfo.price = _price * 10 **18;
        }

        // update product NFT token balance flag
        productInfo.isRequiredNftTokenBalance = _isRequiredNftTokenBalance;

        // update product nftTokenContractAddress
        if(_nftTokenContractAddress != address(0x0)){
             productInfo.nftTokenContractAddress = _nftTokenContractAddress;
        }

        //store updated product information
        nfxProductData[_id] = productInfo;
     
    }

    function deleteProduct(uint256 _id) public onlyOwner {
        // check product id
        require(_id > 0 && _id <= _nextProductId , "NFX#addProduct: product id is not valid");

        NfxProduct memory productInfo = nfxProductData[_id];
        productInfo.isDeleted = true;
        nfxProductData[_id] = productInfo;
    }


    function buyProduct(address _payToken, uint256 _productId) public  {  
        // check message sender
        // require(msg.sender != owner(), "NiftyFlex#buyProduct: owner cannot call this function");

        // check product id
        require(_productId > 0 && _productId <= _nextProductId, "NiftyFlex#buyProduct: productId is not valid");

        // get product information from mapping
        NfxProduct memory productInfo = nfxProductData[_productId];

        // check size id
        require(productInfo.isDeleted == false, "NiftyFlex#buyProduct: the product is not active");

        // check nft token contract flag
        if(productInfo.isRequiredNftTokenBalance) {
            // check nft token balance
            IERC721 nftTokenContract = IERC721(productInfo.nftTokenContractAddress);
            require(nftTokenContract.balanceOf(msg.sender) >= 1, "NiftyFlex#buyProduct: nft token balance is not enough");
        }
     
        // buy product using ASH token
        address  ownerAddress = owner();
        IERC20 ashContract = IERC20(_payToken);       
          
        // check ASH balance of msg.sender
        require(ashContract.balanceOf(msg.sender) >= productInfo.price, "NiftyFlex#buyProduct: ASH token balance is not enough");

        // check ASH allowance of msg.sender
        uint256 allowance = ashContract.allowance(msg.sender, address(this));
        require(allowance >= productInfo.price, "NiftyFlex#buyProduct: ASH token allowance is not enough");
       
        // // transfer ASH from msg.sender to owner wallet
        ashContract.transferFrom(msg.sender, ownerAddress, productInfo.price);

        // mint NFX token to msg.sender
        _nextTokenId += 1;
        _safeMint(msg.sender, _nextTokenId);
    }    
}
