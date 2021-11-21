// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;


abstract contract ICropManager {
    mapping (address => address) public proxy; // UrnProxy per user

    function vat() external virtual view returns (address);
    function getOrCreateProxy(address) external virtual returns (address);
    function join(address, address, uint256) external virtual;
    function exit(address, address, uint256) external virtual;
    function frob(address, address, address, address, int256, int256) external virtual;
    function quit(bytes32 ilk, address dst) external virtual;
}
