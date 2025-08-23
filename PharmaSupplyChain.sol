// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PharmaSupplyChain is Initializable, OwnableUpgradeable {
    struct Shipment {
        uint256 id;
        address sender;
        address receiver;
        uint256 temperatureThresholdMin;
        uint256 temperatureThresholdMax;
        bool isDelivered;
        uint256[] temperatureReadings;
        string[] gpsLocations;
    }

    mapping(uint256 => Shipment) public shipments;

    event TemperatureBreached(uint256 shipmentId, uint256 temperature, uint256 timestamp);
    event DataLogged(uint256 shipmentId, string gpsLocation, uint256 temperature, uint256 timestamp);

    uint256 public shipmentCounter;

    // Constants for temperature thresholds
    uint256 private constant TEMPERATURE_THRESHOLD_MIN = 2;
    uint256 private constant TEMPERATURE_THRESHOLD_MAX = 8;


    function initialize() public initializer {
        __Ownable_init(msg.sender);
        shipmentCounter = 0;
    }

    function initializeShipment(address _receiver) public returns (uint256) {
        shipmentCounter++;
        shipments[shipmentCounter] = Shipment(
            shipmentCounter,
            msg.sender,
            _receiver,
            TEMPERATURE_THRESHOLD_MIN,
            TEMPERATURE_THRESHOLD_MAX,
            false,
            new uint256[](0), // Initialize empty temperature readings array
            new string[](0)
   );

        return shipmentCounter;
    }

    function logData(uint256 _shipmentId,string memory _gpsLocation,uint256 _temperature) public {
        Shipment storage shipment = shipments[_shipmentId];
        require(shipment.id > 0, "Shipment does not exist");
        require(!shipment.isDelivered, "Shipment already delivered");

        shipment.temperatureReadings.push(_temperature);
        shipment.gpsLocations.push(_gpsLocation);

        if (
            _temperature < shipment.temperatureThresholdMin ||
            _temperature > shipment.temperatureThresholdMax
        ) {
            emit TemperatureBreached(_shipmentId, _temperature, block.timestamp);
        }

        emit DataLogged(_shipmentId, _gpsLocation, _temperature, block.timestamp);
    }

    function markAsDelivered(uint256 _shipmentId) public {
        Shipment storage shipment = shipments[_shipmentId];
        require(shipment.id > 0, "Shipment does not exist");
        require(!shipment.isDelivered, "Shipment already delivered");
        require(msg.sender == shipment.receiver, "Only the receiver can mark as delivered");

        shipment.isDelivered = true;
    }

    function getShipment(uint256 _shipmentId)
        public
        view
        returns (
            uint256 id,
            address sender,
            address receiver,
            uint256 temperatureThresholdMin,
            uint256 temperatureThresholdMax,
            bool isDelivered,
            uint256[] memory temperatureReadings,
            string[] memory gpsLocations
        )
    {
        Shipment storage shipment = shipments[_shipmentId];
        require(shipment.id > 0, "Shipment does not exist");

        return (shipment.id,shipment.sender,shipment.receiver,shipment.temperatureThresholdMin,shipment.temperatureThresholdMax,
            shipment.isDelivered, shipment.temperatureReadings,shipment.gpsLocations);
    }
}