source .env

FOUNDRY_PROFILE=external forge script TelepathyValidator.s.sol:Deploy \
  --rpc-url $RPC_100 \
  --private-key $PRIVATE_KEY_100 \
  --broadcast \
  --verifier etherscan \
  --verifier-url https://api.gnosisscan.io/api \
  --etherscan-api-key $ETHERSCAN_API_KEY_100 \
  --verify