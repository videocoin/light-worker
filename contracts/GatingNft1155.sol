// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./LightWorkerDao.sol";
import "./RewardMgr.sol";


/**
 * @dev {ERC1155} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - a pauser role that allows to stop all token transfers
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and pauser
 * roles, as well as the default admin role, which will let it grant both minter
 * and pauser roles to other accounts.
 *
 * _Deprecated in favor of https://wizard.openzeppelin.com/[Contracts Wizard]._
 */
contract GatingNft1155 is Context, AccessControlEnumerable, ERC1155Burnable, ERC1155Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    address daoContract =  address(0);
    mapping (uint => address) listDao;
    mapping (uint => address) listRewardMgr;

    // Token ID enumeration
    uint256[] public tokenIDs;
    mapping (uint256 => bool) public isTokenID;

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE`, and `PAUSER_ROLE` to the account that
     * deploys the contract.
     */
    constructor(string memory uri) ERC1155(uri) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    /**
     * @dev Creates `amount` new tokens for `to`, of token type `id`.
     *
     * See {ERC1155-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have minter role to mint");

        _mint(to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] variant of {mint}.
     */
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have minter role to mint");

        _mintBatch(to, ids, amounts, data);
    }
    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC1155Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have pauser role to pause");
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC1155Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have pauser role to unpause");
        _unpause();
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, ERC1155)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155, ERC1155Pausable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155) {
        
        for (uint256 i = 0; i < ids.length; ++i) {

            // Create Rewards Distribution contract for the node if it does not exist and minting(redundant check ?)
            if(listRewardMgr[i] == address(0) && from == address(0)) {
                listRewardMgr[i] = address(new RewardMgr(address(this), msg.sender, i));
            }

            // Create DAO for the node if it does not exist and minting minting(redundant check ?)
            if(listDao[i] == address(0) && from == address(0)){
                listDao[i] = address(new LightWorkerDao(address(this), msg.sender, listRewardMgr[i], i));
                LightWorkerDao(listDao[i]).addWorker(to);
            }
            _addTokenID(ids[i]);

            // Remove if balance falls to zero
            if(from != address(0) && balanceOf(from, i) == 0) {
                LightWorkerDao(listDao[ids[i]]).removeWorker(from);
            }
            // Add if balance is greater than zero
            if(to != address(0) && balanceOf(to, i) > 0) {
                LightWorkerDao(listDao[ids[i]]).addWorker(to);
            }
        }
    }

    function getRewardMgr(uint tokenID)
        public
        view
        returns (address)
    {
        return listRewardMgr[tokenID];
    }

    function getLightWorkerDao(uint tokenID)
        public
        view
        returns (address)
    {
        return listDao[tokenID];
    }
    // Token ID enumeration
    function _addTokenID(uint tokenID)
        internal
    {
        if(!isTokenID[tokenID]) {
            tokenIDs.push(tokenID);
            isTokenID[tokenID] = true;
        }
    }
    
    function getTokenIDs()
        public
        view
        returns (uint256[] memory)
    {

        uint256[] memory _tokenIDs = new uint256[](tokenIDs.length);

        for (uint256 i = 0; i < tokenIDs.length; ++i) {
            _tokenIDs[i] = tokenIDs[i];
        }
        return _tokenIDs;
    }

    
    function purchaseToken(uint256 tokenId) public payable returns (uint256) {

        require(isTokenID[tokenId], "Invalid Token ID");
  
        // Get the token owner
        address owner =  LightWorkerDao(listDao[tokenId]).getOperator();
        uint tokenPrice = LightWorkerDao(listDao[tokenId]).getTokenPrice();

        require(owner != msg.sender, "You cannot buy your own token");
        require(msg.value == tokenPrice, "You must pay the full price");

        // Transfer the token
        safeTransferFrom(owner, msg.sender, tokenId, 1, "");

        // Make a payment to the owner of the token
        (bool sent,) = payable(owner).call{value:msg.value}("");
        require(sent, "Payment failed");
        return tokenId;
    }

    function redeemToken(uint256 tokenId) public payable returns (uint256) {
        // TODO
    }
}
