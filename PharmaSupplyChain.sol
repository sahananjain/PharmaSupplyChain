
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract PharmaSupplyChainUpgradeable is
    Initializable,
    OwnableUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant SUPPLIER_ROLE = keccak256("SUPPLIER_ROLE");
    bytes32 public constant ORACLE_ROLE   = keccak256("ORACLE_ROLE");

    struct Shipment {
        uint256 id;
        address sender;
        address receiver;
        uint256 temperatureThresholdMin;
        uint256 temperatureThresholdMax;
        bool isDelivered;
        bool isBreached;                  
        uint256[] temperatureReadings;
        string[] gpsLocations;
    }

    mapping(uint256 => Shipment) public shipments;

    event TemperatureBreached(uint256 indexed shipmentId, uint256 temperature, uint256 timestamp);
    event DataLogged(uint256 indexed shipmentId, string gpsLocation, uint256 temperature, uint256 timestamp);
    event ShipmentInitialized(uint256 indexed shipmentId, address indexed sender, address indexed receiver);

    uint256 private TEMPERATURE_THRESHOLD_MIN;
    uint256 private TEMPERATURE_THRESHOLD_MAX;

   
    uint256 public constant MAX_LOG_ENTRIES = 500;      
    uint256 public constant MAX_GPS_LEN     = 80;       

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address initialSupplier, address initialOracle) public initializer {
        __Ownable_init(initialOwner);
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(SUPPLIER_ROLE, initialSupplier);
        _grantRole(ORACLE_ROLE, initialOracle);

        TEMPERATURE_THRESHOLD_MIN = 2;
        TEMPERATURE_THRESHOLD_MAX = 8;
    }

    // --- Admin / Ops controls ---
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function addSupplier(address supplier) external onlyOwner {
        _grantRole(SUPPLIER_ROLE, supplier);
    }

    function removeSupplier(address supplier) external onlyOwner {
        _revokeRole(SUPPLIER_ROLE, supplier);
    }

    function setOracle(address oracle) external onlyOwner {
        _grantRole(ORACLE_ROLE, oracle);
    }

    function revokeOracle(address oracle) external onlyOwner {
        _revokeRole(ORACLE_ROLE, oracle);
    }

    // Supplier initializes shipment
    function initializeShipment(uint256 shipmentId, address receiver) external whenNotPaused onlyRole(SUPPLIER_ROLE) {
        require(receiver != address(0), "Invalid receiver");
        require(shipments[shipmentId].id == 0, "Shipment ID exists");

        Shipment storage s = shipments[shipmentId];
        s.id = shipmentId;
        s.sender = msg.sender;
        s.receiver = receiver;
        s.temperatureThresholdMin = TEMPERATURE_THRESHOLD_MIN;
        s.temperatureThresholdMax = TEMPERATURE_THRESHOLD_MAX;
        s.isDelivered = false;
        s.isBreached = false;

        emit ShipmentInitialized(shipmentId, msg.sender, receiver);
    }

    function logData(uint256 shipmentId, string calldata gpsLocation, uint256 temperature)
        external
        whenNotPaused
        onlyRole(ORACLE_ROLE)
    {
        Shipment storage s = shipments[shipmentId];
        require(s.id != 0, "Shipment missing");
        require(!s.isDelivered, "Already delivered");
        require(bytes(gpsLocation).length <= MAX_GPS_LEN, "GPS too long");
        require(s.temperatureReadings.length < MAX_LOG_ENTRIES, "Log limit reached");

        s.temperatureReadings.push(temperature);
        s.gpsLocations.push(gpsLocation);

        if (temperature < s.temperatureThresholdMin || temperature > s.temperatureThresholdMax) {
            s.isBreached = true; 
            emit TemperatureBreached(shipmentId, temperature, block.timestamp);
        }

        emit DataLogged(shipmentId, gpsLocation, temperature, block.timestamp);
    }


    function markAsDelivered(uint256 shipmentId) external whenNotPaused {
        Shipment storage s = shipments[shipmentId];
        require(s.id != 0, "Shipment missing");
        require(!s.isDelivered, "Already delivered");
        require(msg.sender == s.receiver, "Only receiver");

        s.isDelivered = true;
    }

    function isShipmentBreached(uint256 shipmentId) external view returns (bool) {
        Shipment storage s = shipments[shipmentId];
        require(s.id != 0, "Shipment missing");
        return s.isBreached;
    }

    function getShipment(uint256 shipmentId)
        external
        view
        returns (
            uint256 id,
            address sender,
            address receiver,
            uint256 temperatureThresholdMin,
            uint256 temperatureThresholdMax,
            bool isDelivered,
            bool isBreached,
            uint256[] memory temperatureReadings,
            string[] memory gpsLocations
        )
    {
        Shipment storage s = shipments[shipmentId];
        require(s.id != 0, "Shipment missing");

        return (
            s.id,
            s.sender,
            s.receiver,
            s.temperatureThresholdMin,
            s.temperatureThresholdMax,
            s.isDelivered,
            s.isBreached,
            s.temperatureReadings,
            s.gpsLocations
        );
    }

    function updateTemperatureThresholds(uint256 minTemp, uint256 maxTemp) external onlyOwner {
        require(minTemp < maxTemp, "Bad range");
        TEMPERATURE_THRESHOLD_MIN = minTemp;
        TEMPERATURE_THRESHOLD_MAX = maxTemp;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
