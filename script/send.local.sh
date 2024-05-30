# This calls Anvil and lets us impersonate our unlucky user
ME=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# EETH
UNLUCKY_USER=0x22162DbBa43fE0477cdC5234E248264eC7C6EA7c;
TOKEN=0x35fA164735182de50811E8e2E824cFb9B6118ac2
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