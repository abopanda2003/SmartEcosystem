// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface ISmartArmy {
    /// @dev License Types
    struct LicenseType {
        uint256  level;        // level
        string   name;         // Trial, Opportunist, Runner, Visionary
        uint256  price;        // 100, 1000, 5000, 10,000
        uint256  ladderLevel;  // Level of referral system with this license
        uint256  duration;     // default 6 months
        bool     isValid;
    }

    enum LicenseStatus {
        None,
        Pending,
        Active,
        Expired
    }

    /// @dev User information on license
    struct UserLicense {
        address owner;
        uint256 level;
        uint256 startAt;
        uint256 activeAt;
        uint256 expireAt;
        uint256 lpLocked;

        LicenseStatus status;
    }

    /// @dev User Personal Information
    struct UserPersonal {
        address sponsor;
        string username;
        string telegram;
    }

    /// @dev Fee Info 
    struct FeeInfo {
        uint256 penaltyFeePercent;      // liquidate License LP fee percent
        uint256 extendFeeBNB;       // extend Fee as BNB
        address feeAddress;
    }
    
    function licenseOf(address account) external view returns(UserLicense memory);
    function lockedLPOf(address account) external view returns(uint256);
    function isActiveLicense(address account) external view returns(bool);
    function isEnabledIntermediary(address account) external view returns(bool);
    function licenseLevelOf(address account) external view returns(uint256);
    function licenseActiveDuration(address account, uint256 from, uint256 to) external view returns(uint256, uint256);
}
