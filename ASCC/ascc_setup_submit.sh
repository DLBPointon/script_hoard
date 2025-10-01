### /// FIND YAML FOR PARSING /// ###

cd ascc/

module load speciesops

SAMPLE=bOenLec1
DIR=$(speciesops getdir --tolid $SAMPLE | grep "Species directory path: " | sed "s/Species directory path: //g")

counter=0

for yaml in ${DIR}/assembly/draft/${SAMPLE}.*/*.yaml; do
	species_yaml=$yaml;
	counter=$((counter+1)) ;
	echo "YAML is: $species_yaml"
done

### /// PARSE YAML TO INPUT /// ###

if [[ $counter -eq 1 ]]; then

    echo "Making Decon Dir"
    mkdir -p $(dirname "${species_yaml}")/decon
    DECON_FOLDER=$(dirname "${species_yaml}")/decon

    echo "Making Directory"
    mkdir -p "ASCC_FULL_RUNS/${SAMPLE}/"

    echo "Getting Data from: $species_yaml"
    assembly_line="sample,assembly_type,assembly_file\n"

    ### Attempt to get HAP1
    HAP1=$(grep "^hap1: " $species_yaml | sed "s/hap1: //g")

    ### IF HAP1 is NOT empty then proceed as HAP1/2 case
    ### ELSE this is a primary/hap case
    ### Name it as appropriate
    if [[ -n "$HAP1" ]]; then
        HAP2=$(grep "^hap2: " $species_yaml | sed "s/hap2: //g")
        prim_type="HAP1"
        hap_type="HAP2"
        assembly_line+="${SAMPLE},${prim_type},${HAP1}\n${SAMPLE},${hap_type},${HAP2}\n"
    else
        PRIMARY=$(grep "^primary: " $species_yaml | sed "s/primary: //g")
        HAP2=$(grep "^haplotigs: " $species_yaml | sed "s/haplotigs: //g")
        prim_type="PRIMARY"
        hap_type="HAPLO"
        assembly_line+="${SAMPLE},${prim_type},${HAP1}\n${SAMPLE},${hap_type},${HAP2}\n"
    fi

    ### Now attempt to get organellar data if possible
    ### and add it to a string for output
    MITO=$(grep "^mito: " $species_yaml | sed "s/mito: //g")
    PLASTID=$(grep "^plastid: " $species_yaml | sed "s/plastid: //g")

    if [[ -n "$MITO" ]]; then
        assembly_line+="${SAMPLE},MITO,${MITO}\n"
    fi

    if [[ -n "$PLASTID" ]]; then
        assembly_line+="${SAMPLE},PLASTID,${PLASTID}\n"
    fi

    printf $assembly_line > "ASCC_FULL_RUNS/${SAMPLE}/samplesheet.csv"

    echo "GENERATING PARAMS"
    cp "ASCC_FULL_RUNS/params.yaml" "ASCC_FULL_RUNS/${SAMPLE}/params.yaml"
    chmod +775 "ASCC_FULL_RUNS/${SAMPLE}/params.yaml"

    ### REPLACE TEMPLATE STRINGS WITH ENV VAR
    sed -i "s/SAMPLE/${SAMPLE}/g" "ASCC_FULL_RUNS/${SAMPLE}/params.yaml"

    LATINNAM=$(grep "^species: " "$species_yaml" | sed "s/species: //g")
    BUSCOLIN=$(grep "^busco_lineage: " "$species_yaml" | sed "s/busco_lineage: //g" )
    escaped_name=$(printf '%s\n' "$LATINNAM" | sed 's/[&|]/\\&/g')
    sed -i "s|LATIN_NAME|$escaped_name|g" "ASCC_FULL_RUNS/${SAMPLE}/params.yaml"
    sed -i "s|BUSCO_LIN|"$BUSCOLIN"|g" "ASCC_FULL_RUNS/${SAMPLE}/params.yaml"

    ### Now to get longread data
    pacbio_ph=$(grep "^pacbio_read_dir: " "$species_yaml" | sed "s/pacbio_read_dir: //g" )
    ont_ph=$(grep "^ont_read_dir: " "$species_yaml" | sed "s/ont_read_dir: //g" )

    ### Scan Pacbio Directory for files
    pacbio_list=()
    pacbio_counter=0
    for i in ${pacbio_ph}/fasta/*.fasta.gz; do
        echo "PACBIO: $i"
        pacbio_list+=( "$i" )
        pacbio_counter=$((pacbio_counter+1))
    done

    ### If nothing found in Pacbio Dir, try the ONT dir (implied by no pacbio)
    if [[ $pacbio_list == "/fasta/*.fasta.gz"  ]]; then
        for i in ${ont_ph}/*.fasta.gz; do
            echo "ONT: $i"
            pacbio_list+=( "$i" )
        done
    fi

    ### Format the Array into a string
    pacbio_input=""
    for file in "${pacbio_list[@]}"; do
    	pacbio_input+="\n  - $file"
    done

    ### Format with printf and replace the TEMPLATE var
    replacement=$(printf "%b" "$pacbio_input")
    sed "/READS/ {
        s|READS||g
        r /dev/stdin
    }" "ASCC_FULL_RUNS/${SAMPLE}/params.yaml" <<< "$replacement" > tmp.yaml && mv tmp.yaml "ASCC_FULL_RUNS/${SAMPLE}/params.yaml"


    ### Get barcodes from pacbio files
    bc_input=()
    for file in "${pacbio_list[@]}"; do
        bc_id=$(echo "$file" | grep -oE 'bc[0-9]+')

        if [[ -n "$bc_id" ]]; then
            echo "Found: $bc_id in $file"
            bc_input+=( "$bc_id" )
        else
            echo "No Barcode: $file"
        fi
    done

    ### If no barcodes, such as in ONT then add this dummy
    if [[ $bc_input == "" ]]; then
        bc_input+=( "bc2025" )
    fi

    ### Create Unique array of barcodes, duplicates will break the pipeline
    unique_bc=()
    while read -r line; do
        unique_bc+=( "$line" )
    done < <(printf "%s\n" "${bc_input[@]}" | sort -u)

    joined_bc=$(IFS=,; echo "${unique_bc[*]}")

    echo "Final bc_input: $joined_bc"

    sed -i "s|BARCODE|${joined_bc}|g" "ASCC_FULL_RUNS/${SAMPLE}/params.yaml"
else
    echo "Too many Yaml"
fi

### Remove lines of `    - /fasta/*fasta.gz`
### Remnant from the fasta search
sed -i '/  - \/fasta\//d' ASCC_FULL_RUNS/${SAMPLE}/params.yaml

echo "SAMPLESHEET"
cat "ASCC_FULL_RUNS/${SAMPLE}/samplesheet.csv"
echo "PARAMS FILE"
cat "ASCC_FULL_RUNS/${SAMPLE}/params.yaml"

### /// CHANGE TAXID /// ###

new_taxid=391703
sed -i "s|TAXID|$new_taxid|g" "ASCC_FULL_RUNS/${SAMPLE}/params.yaml"
cat "ASCC_FULL_RUNS/${SAMPLE}/params.yaml"

### /// SUBMIT JOB /// ###

mkdir ASCC_FULL_OUTPUT/${SAMPLE}
cd ASCC_FULL_OUTPUT/${SAMPLE}

export NXF_SINGULARITY_NEW_PID_NAMESPACE=false
bsub -Is -tty -e test.e -o test.log -n 2 -q oversubscribed -M1200 -R'select[mem>1200] rusage[mem=1200] span[hosts=1]' "nextflow run ../../main.nf -params-file /lustre/scratch124/tol/teams/tola/users/dp24/ascc/ASCC_FULL_RUNS/${SAMPLE}/params.yaml --outdir /lustre/scratch124/tol/teams/tola/users/dp24/ascc/ASCC_FULL_OUTPUT/${SAMPLE}/ -profile production,sanger,singularity -resume"

### /// Move to DECON /// ###
echo $DECON_FOLDER
cp -r ${SAMPLE} ${DECON_FOLDER}
cp ../../ASCC_FULL_RUNS/${SAMPLE}/samplesheet.csv ${DECON_FOLDER}/${SAMPLE}/sample_sheet.csv
cat ${DECON_FOLDER}/${SAMPLE}/sample_sheet.csv
