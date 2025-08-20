FCS_NODE_LOOKUP

FCSGX a tool used in ASCC was misbehaving and so to investigate timings of FCS jobs I wrote all this.


Use this bash:
```bash
grep "name: SANGERTOL_ASCC:ASCC:GENOMIC:RUN_FCSGX:FCSGX_RUNGX\|name: SANGERTOL_ASCC:ASCC:ORGANELLAR:RUN_FCSGX:FCSGX_RUNGX" */.nextflow.log | cut -d ";" -f 3,7 | sed -e  s'/started*\:.*//g' -e 's/;/:/g' -e 's/ //g' | grep -v "xgCyaNati5" | cut -d ":" -f 4,6,8 > fcs-jobs-running-now.txt
```

Which generates:
```
ORGANELLAR:FCSGX_RUNGX(bCalBor7_MITO):/lustre/scratch124/tol/teams/tola/users/dp24/ascc/bCalBor7/work/7b/423157a2ae134cb83ce41c44916f99
GENOMIC:FCSGX_RUNGX(bCalBor7_HAPLO):/lustre/scratch124/tol/teams/tola/users/dp24/ascc/bCalBor7/work/d1/e9130df5a5264e6eb06e5ef237c595
```

Run the script
```
fcs_node_lookup.py above_file.txt {ALL|PASS|FAILED}
```

Outputs:
```
bCalBor7_HAPLO_GENOMIC_074dc63d9ea5236cf0c807ad2e639c
	- NODE: tol-1-11-2
	- STAT: FAILED
	- STIME: 2025-07-15 16:02:01
	- ETIME: 2025-07-15 16:03:13
	- DTIME: 1.2
	- LOGS: /lustre/scratch124/tol/teams/tola/users/dp24/ascc/bCalBor7/work/17/074dc63d9ea5236cf0c807ad2e639c/.command.log

bCalBor7_HAPLO_GENOMIC_1b56dfb60697a180a3659ee5d25bfc
	- NODE: tol-1-11-1
	- STAT: FAILED
	- STIME: 2025-07-15 12:55:49
	- ETIME: 2025-07-15 13:10:44
	- DTIME: 14.916666666666666
	- LOGS: /lustre/scratch124/tol/teams/tola/users/dp24/ascc/bCalBor7/work/2a/1b56dfb60697a180a3659ee5d25bfc/.command.log
```
