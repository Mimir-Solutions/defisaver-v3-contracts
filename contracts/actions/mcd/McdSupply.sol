// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import "../../interfaces/mcd/IManager.sol";
import "../../interfaces/mcd/ICropManager.sol";
import "../../interfaces/mcd//IVat.sol";
import "../../interfaces/mcd//IJoin.sol";
import "../../utils/TokenUtils.sol";
import "../ActionBase.sol";
import "./helpers/McdHelper.sol";

/// @title Supply collateral to a Maker vault
contract McdSupply is ActionBase, McdHelper {
    using TokenUtils for address;

    /// @inheritdoc ActionBase
    function executeAction(
        bytes[] memory _callData,
        bytes[] memory _subData,
        uint8[] memory _paramMapping,
        bytes32[] memory _returnValues
    ) public payable override returns (bytes32) {
        (uint256 vaultId, uint256 amount, address joinAddr, address from, address mcdManager, bool isCrop) =
            parseInputs(_callData);

        vaultId = _parseParamUint(vaultId, _paramMapping[0], _subData, _returnValues);
        amount = _parseParamUint(amount, _paramMapping[1], _subData, _returnValues);
        joinAddr = _parseParamAddr(joinAddr, _paramMapping[2], _subData, _returnValues);
        from = _parseParamAddr(from, _paramMapping[3], _subData, _returnValues);

        uint256 returnAmount = _mcdSupply(vaultId, amount, joinAddr, from, mcdManager, isCrop);

        return bytes32(returnAmount);
    }

    /// @inheritdoc ActionBase
    function executeActionDirect(bytes[] memory _callData) public payable override {
        (uint256 vaultId, uint256 amount, address joinAddr, address from, address mcdManager, bool isCrop) =
            parseInputs(_callData);

        _mcdSupply(vaultId, amount, joinAddr, from, mcdManager, isCrop);
    }

    /// @inheritdoc ActionBase
    function actionType() public pure override returns (uint8) {
        return uint8(ActionType.STANDARD_ACTION);
    }

    //////////////////////////// ACTION LOGIC ////////////////////////////

    /// @notice Supplies collateral to the vault
    /// @param _vaultId Id of the vault
    /// @param _amount Amount of tokens to supply
    /// @param _joinAddr Join address of the maker collateral
    /// @param _from Address where to pull the collateral from
    /// @param _mcdManager The manager address we are using [mcd, b.protocol]
    function _mcdSupply(
        uint256 _vaultId,
        uint256 _amount,
        address _joinAddr,
        address _from,
        address _mcdManager,
        bool isCrop
    ) internal returns (uint256) {
        address tokenAddr = getTokenFromJoin(_joinAddr);

        // if amount type(uint).max, pull current _from balance
        if (_amount == type(uint256).max) {
            _amount = tokenAddr.getBalance(_from);
        }

        // Pull the underlying token and join the maker join pool
        tokenAddr.pullTokensIfNeeded(_from, _amount);
        tokenAddr.approveToken(_joinAddr, _amount);

        _joinCollateral(_mcdManager, _joinAddr, _amount, isCrop);

        // format the amount we need for frob
        int256 convertAmount = toPositiveInt(convertTo18(_joinAddr, _amount));

        // Supply to the vault balance
        _frob(_mcdManager, _joinAddr, _vaultId, convertAmount, isCrop);

        logger.Log(
            address(this),
            msg.sender,
            "McdSupply",
            abi.encode(_vaultId, _amount, _joinAddr, _from, _mcdManager)
        );

        return _amount;
    }

    function _joinCollateral(address _mcdManager, address _joinAddr, uint256 _amount, bool _isCrop) internal {
        if (_isCrop) {
            ICropManager(_mcdManager).join(_joinAddr, address(this), _amount);
        } else {
            IJoin(_joinAddr).join(address(this), _amount);
        }
    }

    function _frob(address _mcdManager, address _joinAddr, uint256 _vaultId, int256 _amount, bool _isCrop) internal {
        if (_isCrop) {
            ICropManager(_mcdManager).frob(_joinAddr, address(this), address(this), address(this), _amount, 0);
        } else {
            vat.frob(
                IManager(_mcdManager).ilks(_vaultId),
                IManager(_mcdManager).urns(_vaultId),
                address(this),
                address(this),
                _amount,
                0
            );
        }
    }

    function parseInputs(bytes[] memory _callData)
        internal
        pure
        returns (
            uint256 vaultId,
            uint256 amount,
            address joinAddr,
            address from,
            address mcdManager,
            bool isCrop
        )
    {
        vaultId = abi.decode(_callData[0], (uint256));
        amount = abi.decode(_callData[1], (uint256));
        joinAddr = abi.decode(_callData[2], (address));
        from = abi.decode(_callData[3], (address));
        mcdManager = abi.decode(_callData[4], (address));
        isCrop = abi.decode(_callData[5], (bool));
    }
}
