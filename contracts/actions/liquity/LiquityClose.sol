// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import "./helpers/LiquityHelper.sol";
import "../../utils/TokenUtils.sol";
import "../ActionBase.sol";

contract LiquityClose is ActionBase, LiquityHelper {
    using TokenUtils for address;

    /// @inheritdoc ActionBase
    function executeAction(
        bytes[] memory _callData,
        bytes[] memory _subData,
        uint8[] memory _paramMapping,
        bytes32[] memory _returnValues
    ) public payable virtual override returns (bytes32) {
        (
            address from,
            address to
        ) = parseInputs(_callData);

        from = _parseParamAddr(from, _paramMapping[0], _subData, _returnValues);
        to = _parseParamAddr(to, _paramMapping[1], _subData, _returnValues);

        uint256 coll = _liquityClose(from, to);
        return bytes32(coll);
    }

    /// @inheritdoc ActionBase
    function executeActionDirect(bytes[] memory _callData) public virtual payable override {
        (
            address from,
            address to
        )= parseInputs(_callData);

        _liquityClose(from, to);
    }

    /// @inheritdoc ActionBase
    function actionType() public pure virtual override returns (uint8) {
        return uint8(ActionType.STANDARD_ACTION);
    }

    //////////////////////////// ACTION LOGIC ////////////////////////////

    /// @notice Opens up an empty trove
    function _liquityClose(address _from, address _to) internal returns (uint256) {
        uint256 debt = TroveManager.getTroveDebt(address(this));
        uint256 coll = TroveManager.getTroveColl(address(this));

        LUSDTokenAddr.pullTokensIfNeeded(_from, debt);
        
        BorrowerOperations.closeTrove();

        TokenUtils.depositWeth(coll);
        TokenUtils.WETH_ADDR.withdrawTokens(_to, coll);

        logger.Log(
            address(this),
            msg.sender,
            "LiquityClose",
            abi.encode(_from, _to, debt, coll)
        );

        return uint256(coll);
    }

    function parseInputs(bytes[] memory _callData)
        internal
        pure
        returns (
            address from,
            address to
        )
    {
        from = abi.decode(_callData[0], (address));
        to = abi.decode(_callData[1], (address));
    }
}