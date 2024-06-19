# This calls Anvil and lets us impersonate our unlucky user
ME=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# EETH
UNLUCKY_USER=0x78605Df79524164911C144801f41e9811B7DB73D;
TOKEN=0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa
AMOUNT=100000000000000000000
cast rpc anvil_impersonateAccount $UNLUCKY_USER
cast send $TOKEN \
--from $UNLUCKY_USER \
  "transfer(address,uint256)(bool)" \
  $ME \
  $AMOUNT \
  --unlocked

# SWETEH
# UNLUCKY_USER=0x38D43a6Cb8DA0E855A42fB6b0733A0498531d774;
# TOKEN=0xf951E335afb289353dc249e82926178EaC7DEd78
# AMOUNT=800000000000000000000
# cast rpc anvil_impersonateAccount $UNLUCKY_USER
# cast send $TOKEN \
# --from $UNLUCKY_USER \
#   "transfer(address,uint256)(bool)" \
#   $ME \
#   $AMOUNT \
#   --unlocked