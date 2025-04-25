## How to simulate on workstation (tb.v is a testbench using pattern1 for simulation)

```bash
vcs GSIM.v tb.v +define+RV32I+RTL -full64 -R -debug_access+all +v2k
```

## If you want to sythesis on workstation
change .synopsys_dc.setup file to the setup we used in HW2, the setup in EXERCISE is for ADFP

## How to login to ADFP workstation
[Access the workstation](https://140.112.33.156/)
account: dsd010
password: 7ujPtxOLNn

you can turn on the terminal on workstation and directly execute
```bash
dc_shell -f syn.tcl
```
read N16_ADFP_tutorial for more informations
