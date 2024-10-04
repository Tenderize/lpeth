#!/bin/bash
set -x
source .env

nohup bash -c "anvil --block-time 2 --fork-url ${MAINNET_RPC} --chain-id 1337 &" >/dev/null 2>&1 && sleep 5

forge build

curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","id":67,"method":"anvil_setCode","params": ["0x4e59b44847b379578588920ca78fbf26c0b4956c","0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3"]}' 127.0.0.1:8545

export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

 forge script script/deploy.local.s.sol --legacy --rpc-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY -vvvv
 forge script script/add_liq.s.sol --legacy --rpc-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY -vvvv
# forge script script/prelaunch.local.s.sol --legacy --rpc-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY -vvvv

read -r -d '' _ </dev/tty
echo "Closing Down Anvil"
pkill -9 anvil