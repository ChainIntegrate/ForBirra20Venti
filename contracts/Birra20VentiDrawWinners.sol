// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { LSP8IdentifiableDigitalAsset } from "@lukso/lsp8-contracts/contracts/LSP8IdentifiableDigitalAsset.sol";
import {
  _LSP4_METADATA_KEY,
  _LSP4_TOKEN_TYPE_NFT
} from "@lukso/lsp4-contracts/contracts/LSP4Constants.sol";
import { _LSP8_TOKENID_FORMAT_STRING } from "@lukso/lsp8-contracts/contracts/LSP8Constants.sol";

/**
 * Birra20VentiDrawWinners (V2)
 *
 * Collezione NFT UNICA e riutilizzabile per tutte le estrazioni a premi.
 * Ogni estrazione pubblicata nell'Albo (estrazioni_archive.json) puo' generare
 * al massimo UN token, con tokenId = ID dell'estrazione (es. "E1XX").
 *
 * UP-only, stesso schema del contratto First10Purchases2026:
 * - owner del contratto = UP del birrificio
 * - solo l'owner puo' coniare (mint) e congelare i metadata
 * - ogni token, una volta congelato, ha metadata immutabili
 *
 * Rispetto alla V1:
 * - LSP4TokenType = NFT (1), non TOKEN (0): un premio unico va tra i
 *   Collectibles della UP, non tra gli Assets/valute.
 * - Il valore di LSP4Metadata NON viene piu' incapsulato a mano dentro il
 *   contratto (bytes4(0)+bytes32(0)+url, come faceva First10Purchases2026_V3).
 *   Va invece calcolato correttamente FUORI dalla blockchain con erc725.js
 *   (che calcola l'hash keccak256 reale del JSON) e passato qui gia' pronto
 *   come `bytes`. Il contratto si limita a scriverlo. Vedi script di mint
 *   allegato (mint_draw_winner.js).
 */
contract Birra20VentiDrawWinners is LSP8IdentifiableDigitalAsset {
  mapping(bytes32 => bool) public metadataFrozen;

  event DrawWinnerMinted(bytes32 indexed tokenId, address indexed to);
  event MetadataUpdated(bytes32 indexed tokenId);
  event MetadataFrozen(bytes32 indexed tokenId);

  error MetadataIsFrozen(bytes32 tokenId);
  error InvalidUP(address up);
  error TokenAlreadyMinted(bytes32 tokenId);

  constructor(
    string memory name_,
    string memory symbol_,
    address up_ // l'UP del birrificio — deve essere un contract, owner della collezione
  )
    LSP8IdentifiableDigitalAsset(
      name_,
      symbol_,
      up_,
      _LSP4_TOKEN_TYPE_NFT,
      _LSP8_TOKENID_FORMAT_STRING
    )
  {
    if (up_ == address(0)) revert InvalidUP(up_);
    if (up_.code.length == 0) revert InvalidUP(up_);
  }

  /**
   * Conia il token per il vincitore di una specifica estrazione e ne imposta
   * subito i metadata (gia' correttamente incapsulati con erc725.js fuori
   * dalla catena — vedi mint_draw_winner.js).
   *
   * @param drawId l'ID dell'estrazione, es. "E1XX" (stesso ID di estrazioni_archive.json)
   * @param to il wallet del cliente vincitore (oggi un EOA gestito da voi;
   *           funziona anche se in futuro sara' una Universal Profile)
   * @param encodedMetadata il valore LSP4Metadata gia' incapsulato (VerifiableURI)
   *        prodotto da ERC725.encodeData(...) lato JavaScript — NON un URL nudo
   */
  function mintDrawWinner(
    string calldata drawId,
    address to,
    bytes calldata encodedMetadata
  ) external onlyOwner {
    bytes32 tokenId = _stringToTokenId(drawId);

    if (_exists(tokenId)) revert TokenAlreadyMinted(tokenId);

    // force=true: consente il mint sia verso EOA (caso attuale) sia verso
    // contratti/UP senza richiedere che implementino LSP1UniversalReceiver
    _mint(to, tokenId, true, "");
    _setMetadata(tokenId, encodedMetadata);

    emit DrawWinnerMinted(tokenId, to);
  }

  /// Permette di correggere i metadata di un token gia' coniato, se non ancora congelati
  function setDrawMetadata(string calldata drawId, bytes calldata encodedMetadata) external onlyOwner {
    bytes32 tokenId = _stringToTokenId(drawId);
    _setMetadata(tokenId, encodedMetadata);
    emit MetadataUpdated(tokenId);
  }

  function freezeDrawMetadata(string calldata drawId) external onlyOwner {
    bytes32 tokenId = _stringToTokenId(drawId);
    if (metadataFrozen[tokenId]) revert MetadataIsFrozen(tokenId);
    metadataFrozen[tokenId] = true;
    emit MetadataFrozen(tokenId);
  }

  function _setMetadata(bytes32 tokenId, bytes calldata encodedMetadata) internal {
    if (metadataFrozen[tokenId]) revert MetadataIsFrozen(tokenId);
    _setDataForTokenId(tokenId, _LSP4_METADATA_KEY, encodedMetadata);
  }

  function _stringToTokenId(string calldata drawId) internal pure returns (bytes32) {
    bytes memory b = bytes(drawId);
    require(b.length > 0 && b.length <= 32, "drawId deve stare in 32 byte");
    return bytes32(b);
  }
}
