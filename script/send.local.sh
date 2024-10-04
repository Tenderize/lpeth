# This calls Anvil and lets us impersonate our unlucky user
ME=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
AMOUNT=100000000000000000000

# EETH
# UNLUCKY_USER=0x78605Df79524164911C144801f41e9811B7DB73D;
# TOKEN=0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa
# cast rpc anvil_impersonateAccount $UNLUCKY_USER
# cast send $TOKEN \
# --from $UNLUCKY_USER \
#   "transfer(address,uint256)(bool)" \
#   $ME \
#   $AMOUNT \
#   --unlocked

# SWETH
UNLUCKY_USER=0x1D812A7E929D4dBe237926ED8e7c31434b9Ab469;
TOKEN=0xf951E335afb289353dc249e82926178EaC7DEd78
AMOUNT=800000000000000000000
cast rpc anvil_impersonateAccount $UNLUCKY_USER
cast send $TOKEN \
--from $UNLUCKY_USER \
  "transfer(address,uint256)(bool)" \
  $ME \
  $AMOUNT \
  --unlocked

# mETH
# TOKEN=0xd5f7838f5c461feff7fe49ea5ebaf7728bb0adfa
# UNLUCKY_USER=0xb937bf362cd897e05eb3d351575598c4f9b55839
# cast rpc anvil_impersonateAccount $UNLUCKY_USER
# cast send $TOKEN \
# --from $UNLUCKY_USER \
#   "transfer(address,uint256)(bool)" \
#   $ME \
#   $AMOUNT \
#   --unlocked