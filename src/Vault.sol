// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "openzeppelin-contracts/proxy/Clones.sol";
import "openzeppelin-contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/token/ERC1155/IERC1155Receiver.sol";
import "openzeppelin-contracts/interfaces/IERC1271.sol";
import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";

import "./VaultRegistry.sol";

error AlreadyInitialized();

contract Vault is Initializable {
    // before any transfer
    // check nft ownership
    // extensible as fuck

    address vaultRegistry;
    address tokenCollection;
    uint256 tokenId;

    function initialize(
        address _vaultRegistry,
        address _tokenCollection,
        uint256 _tokenId
    ) public initializer {
        vaultRegistry = _vaultRegistry;
        require(
            address(this) ==
                VaultRegistry(vaultRegistry).getVault(
                    _tokenCollection,
                    _tokenId
                ),
            "Not vault"
        );
        tokenCollection = _tokenCollection;
        tokenId = _tokenId;
    }

    modifier onlyOwner() {
        require(
            msg.sender == IERC721(tokenCollection).ownerOf(tokenId),
            "Not owner"
        );
        _;
    }

    modifier onlyVault() {
        require(
            address(this) ==
                VaultRegistry(vaultRegistry).getVault(tokenCollection, tokenId),
            "Not vault"
        );
        _;
    }

    function execTransaction(
        address payable to,
        uint256 value,
        bytes calldata data
    ) public payable onlyVault onlyOwner {
        (bool success, bytes memory result) = to.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function isValidSignature(bytes32 _hash, bytes memory _signature)
        public
        view
        onlyVault
        returns (bytes4 magicValue)
    {
        bool isValid = SignatureChecker.isValidSignatureNow(
            IERC721(tokenCollection).ownerOf(tokenId),
            _hash,
            _signature
        );

        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }
    }

    // receiver functions

    receive() external payable {}

    fallback() external payable {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata /* data */
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}