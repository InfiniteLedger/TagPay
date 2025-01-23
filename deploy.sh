source .env

forge script script/TagStream.s.sol:TagStreamScript \
    --rpc-url "https://sepolia.optimism.io" \
	--verify \
    --verifier blockscout \
    --verifier-url "https://optimism-sepolia.blockscout.com/api/" \
    --private-key $PRIVATE_KEY \
    --broadcast 