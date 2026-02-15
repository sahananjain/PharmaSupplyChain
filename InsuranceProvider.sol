
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IPharmaSupplyChain {
    function isShipmentBreached(uint256 shipmentId) external view returns (bool);
}

contract InsuranceProviderUpgradeable is
    Initializable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    struct Policy {
        uint256 policyId;
        uint256 shipmentId;
        address policyHolder;
        uint256 premiumAmount;
        uint256 claimAmount;
        bool isActive;
        bool premiumPaid;       
        bool isClaimed;
        bool isClaimApproved;
    }

    mapping(uint256 => Policy) public policies;

    IPharmaSupplyChain public pharma;

    event PolicyCreated(uint256 indexed policyId, uint256 indexed shipmentId, address indexed policyHolder);
    event PremiumPaid(uint256 indexed policyId, uint256 amount);
    event ClaimFiled(uint256 indexed policyId);
    event ClaimApproved(uint256 indexed policyId);
    event ClaimDeclined(uint256 indexed policyId);
    event ClaimPaid(uint256 indexed policyId, uint256 amount);
    event PolicyDeactivated(uint256 indexed policyId);
    event FundsDeposited(address indexed depositor, uint256 amount);
    event EtherReceived(address indexed sender, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address pharmaSupplyChainAddress) public initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        require(pharmaSupplyChainAddress != address(0), "Invalid PharmaSupplyChain");
        pharma = IPharmaSupplyChain(pharmaSupplyChainAddress);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function setPharmaSupplyChain(address newAddr) external onlyOwner {
        require(newAddr != address(0), "Invalid address");
        pharma = IPharmaSupplyChain(newAddr);
    }

    function createPolicy(
        uint256 policyId,
        uint256 shipmentId,
        address policyHolder,
        uint256 premiumAmount,
        uint256 claimAmount
    ) external whenNotPaused onlyOwner {
        require(policyHolder != address(0), "Invalid holder");
        require(policies[policyId].policyId == 0, "Policy exists");
        require(premiumAmount > 0 && claimAmount > 0, "Bad amounts");

        policies[policyId] = Policy({
            policyId: policyId,
            shipmentId: shipmentId,
            policyHolder: policyHolder,
            premiumAmount: premiumAmount,
            claimAmount: claimAmount,
            isActive: true,
            premiumPaid: false,
            isClaimed: false,
            isClaimApproved: false
        });

        emit PolicyCreated(policyId, shipmentId, policyHolder);
    }

    function payPremium(uint256 policyId) external payable whenNotPaused {
        Policy storage p = policies[policyId];
        require(p.isActive, "Inactive policy");
        require(p.policyHolder == msg.sender, "Only holder");
        require(!p.premiumPaid, "Premium already paid");
        require(msg.value == p.premiumAmount, "Wrong premium");

        p.premiumPaid = true;
        emit PremiumPaid(policyId, msg.value);
    }

    function fileClaim(uint256 policyId) external whenNotPaused {
        Policy storage p = policies[policyId];
        require(p.isActive, "Inactive policy");
        require(p.policyHolder == msg.sender, "Only holder");
        require(p.premiumPaid, "Premium unpaid");
        require(!p.isClaimed, "Already claimed");

        require(pharma.isShipmentBreached(p.shipmentId), "No breach detected");

        p.isClaimed = true;
        emit ClaimFiled(policyId);
    }

    
    function approveClaim(uint256 policyId) external whenNotPaused onlyOwner {
        Policy storage p = policies[policyId];
        require(p.isActive, "Inactive policy");
        require(p.isClaimed, "No claim filed");
        require(!p.isClaimApproved, "Already approved");
        require(pharma.isShipmentBreached(p.shipmentId), "No breach detected");

        p.isClaimApproved = true;
        emit ClaimApproved(policyId);
    }

    function declineClaim(uint256 policyId) external whenNotPaused onlyOwner {
        Policy storage p = policies[policyId];
        require(p.isActive, "Inactive policy");
        require(p.isClaimed, "No claim filed");
        require(!p.isClaimApproved, "Already approved");

        p.isClaimed = false;
        emit ClaimDeclined(policyId);
    }

    
    function payClaim(uint256 policyId) external whenNotPaused nonReentrant onlyOwner {
        Policy storage p = policies[policyId];
        require(p.isActive, "Inactive policy");
        require(p.isClaimed && p.isClaimApproved, "Not approved/claimed");
        require(address(this).balance >= p.claimAmount, "Insufficient balance");
 
        p.isActive = false;

        (bool success, ) = payable(p.policyHolder).call{value: p.claimAmount}("");
        require(success, "Transfer failed");

        emit ClaimPaid(policyId, p.claimAmount);
        emit PolicyDeactivated(policyId);
    }

    function depositFunds() external payable whenNotPaused onlyOwner {
        require(msg.value > 0, "Zero deposit");
        emit FundsDeposited(msg.sender, msg.value);
    }

    receive() external payable { emit EtherReceived(msg.sender, msg.value); }
    fallback() external payable { emit EtherReceived(msg.sender, msg.value); }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
