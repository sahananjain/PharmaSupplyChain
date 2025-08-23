// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13; // Changed to a specific stable patch version for better reliability

// Import OpenZeppelin's ReentrancyGuard to protect against reentrancy attacks.
import "OpenZeppelin/openzeppelin-contracts@4.8.2/contracts/security/ReentrancyGuard.sol";


contract InsuranceProvider is ReentrancyGuard {
    // Policy struct remains unchanged
    struct Policy {
        uint256 policyId;
        uint256 shipmentId;
        address policyHolder;
        uint256 premiumAmount;
        uint256 claimAmount;
        bool isActive;
        bool isClaimed;
        bool isClaimApproved;
    }

    mapping(uint256 => Policy) public policies;
    
    // Mark insuranceProvider as immutable since it is set only once in the constructor.
    address public immutable insuranceProvider;

    // Events: (unchanged)
    event PolicyCreated(uint256 policyId, uint256 shipmentId, address policyHolder);
    event PremiumPaid(uint256 policyId, uint256 amount);
    event ClaimFiled(uint256 policyId);
    event ClaimApproved(uint256 policyId);
    event ClaimDeclined(uint256 policyId);
    event ClaimPaid(uint256 policyId, uint256 amount);
    event PolicyDeactivated(uint256 policyId);
    event EtherReceived(address sender, uint256 amount);
    event FundsDeposited(address depositor, uint256 amount);

    constructor() {
        // Set the insurance provider to the address deploying the contract.
        insuranceProvider = msg.sender;
    }

    // Create a new policy with user-defined policy ID
    function createPolicy(
        uint256 _policyId,
        uint256 _shipmentId,
        address _policyHolder,
        uint256 _premiumAmount,
        uint256 _claimAmount
    ) public {
        require(msg.sender == insuranceProvider, "Only insurance provider can create policies");
        require(policies[_policyId].policyId == 0, "Policy ID already exists");

        policies[_policyId] = Policy(
            _policyId,
            _shipmentId,
            _policyHolder,
            _premiumAmount,
            _claimAmount,
            true, // isActive
            false, // isClaimed
            false  // isClaimApproved
        );

        emit PolicyCreated(_policyId, _shipmentId, _policyHolder);
    }

    // Pay the premium for a policy.
    function payPremium(uint256 _policyId) public payable {
        Policy storage policy = policies[_policyId];
        require(policy.isActive, "Policy is not active");
        require(policy.policyHolder == msg.sender, "Only the policy holder can pay the premium");
        require(msg.value == policy.premiumAmount, "Incorrect premium amount");

        emit PremiumPaid(_policyId, msg.value);
    }

    // File a claim for a policy.
    function fileClaim(uint256 _policyId) public {
        Policy storage policy = policies[_policyId];
        require(policy.isActive, "Policy is not active");
        require(policy.policyHolder == msg.sender, "Only the policy holder can file a claim");
        require(!policy.isClaimed, "Claim already filed");

        policy.isClaimed = true;

        emit ClaimFiled(_policyId);
    }

    // Approve a filed claim.
    function approveClaim(uint256 _policyId) public {
        Policy storage policy = policies[_policyId];
        require(msg.sender == insuranceProvider, "Only insurance provider can approve claims");
        require(policy.isClaimed, "Claim has not been filed");
        require(!policy.isClaimApproved, "Claim already approved");

        policy.isClaimApproved = true;

        emit ClaimApproved(_policyId);
    }

    // Decline a filed claim.
    function declineClaim(uint256 _policyId) public {
        Policy storage policy = policies[_policyId];
        require(msg.sender == insuranceProvider, "Only insurance provider can decline claims");
        require(policy.isClaimed, "Claim has not been filed");
        require(!policy.isClaimApproved, "Claim already approved");

        // Reset claim status without deactivating the policy.
        policy.isClaimed = false;
        emit ClaimDeclined(_policyId);
    }

    // Pay an approved claim.
    // Added nonReentrant modifier from ReentrancyGuard.
    function payClaim(uint256 _policyId) public nonReentrant {
        Policy storage policy = policies[_policyId];
        require(msg.sender == insuranceProvider, "Only insurance provider can pay claims");
        require(policy.isClaimApproved, "Claim is not approved");
        require(policy.isActive, "Policy is not active");
        require(address(this).balance >= policy.claimAmount, "Insufficient contract balance");

        // EFFECTS: Update state before making the external call.
        policy.isActive = false;

        // INTERACTIONS: Transfer funds to the policy holder.
        payable(policy.policyHolder).transfer(policy.claimAmount);

        // Emit events after external interactions.
        emit ClaimPaid(_policyId, policy.claimAmount);
        emit PolicyDeactivated(_policyId);
    }

    // Deactivate a policy.
    function deactivatePolicy(uint256 _policyId) public {
        Policy storage policy = policies[_policyId];
        require(msg.sender == insuranceProvider, "Only insurance provider can deactivate policies");
        require(policy.isActive, "Policy is already inactive");

        policy.isActive = false;
        emit PolicyDeactivated(_policyId);
    }

    // Deposit funds into the contract.
    function depositFunds() public payable {
        require(msg.sender == insuranceProvider, "Only insurance provider can deposit funds");
        require(msg.value > 0, "Deposit amount must be greater than zero");
        emit FundsDeposited(msg.sender, msg.value);
    }

    // View contract balance.
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Fallback function to handle Ether transactions.
    fallback() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }

    // Receive function to handle direct Ether transfers.
    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }
}
