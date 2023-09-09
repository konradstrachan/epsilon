// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// TODO peanut interface
interface IPeanutV4 {
    function makeDeposit(
        address _tokenAddress,
        uint8 _contractType,
        uint256 _amount,
        uint256 _tokenId,
        address _pubKey20
    ) external payable returns (uint256);
}

contract PeanutForwarder {
    constructor() {}

    // Fallback function must be declared as external.
    fallback() external payable {
        createLink();
    }

    // Receive is a variant of fallback that is triggered when msg.data is empty
    receive() external payable {
        createLink();
    }

    function abiPeanutEncode(
        uint256 amount,
        address pubKey20
    ) public pure returns (bytes memory) {
        return abi.encodePacked(address(0), uint8(0), amount, uint256(0), pubKey20);
    }

    function createLink() internal {
        // Taken from https://github.com/peanutprotocol/peanut-contracts/blob/main/contracts.json
        address peanutV4Address = address(0x891021b34fEDC18E36C015BFFAA64a2421738906);
        uint256 amount = uint256(bytes32(msg.data[0:32]));
        address pubKey20 = address(uint160(bytes20(msg.data[32:52])));

        IPeanutV4(peanutV4Address).makeDeposit(address(0), uint8(0), amount, uint256(0), pubKey20);
    }

}