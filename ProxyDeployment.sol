// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract ProxyDeployment {
    TransparentUpgradeableProxy public proxy;

    function deployProxy(address logicAddress, address adminAddress, bytes memory data) public {
        proxy = new TransparentUpgradeableProxy(logicAddress, adminAddress, data);
    }

    function getProxyAddress() public view returns (address) {
        return address(proxy);
    }
}