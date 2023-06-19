#!/bin/bash
#OJO, esto no está bien hecho, porque falta hacer que sea paired end; TODO.
#Falta chequear para si es on no PAIRED-END de forma automática

#ESTO ES UNA COPIA DE PRUEBAS.SH NO COMPLETA!!!!

installcheck () { #$1 name of program
    count=1
    while true;
    do
        echo "Checking if $1 is installed on the system"
        if command -v $1 &> /dev/null
        then
            echo "$1 is installed. Running code..."
            break
        else
            echo "$1 is not installed"
            exit 0 #Esta linea se debería quitar en un futuro
            sudo apt update
            sudo apt install $1
            count=$((count+1))
            echo "$1 should be now installed."
        fi
        if [[ $count == 3 ]]; then
            echo "ERROR: la instalación de $1 ha fallado por motivos desconocidos, con count = $count"
            exit 0
        fi
    done
}
pipeline() { #$1=pairend $2=runtest
    mkdir sam
    for file in $(ls ./fq)
    do
        if [[ $file == *1.fq ]]; then
            echo "Check #1, entra en for, archivo: $file"
            if [[ $1 ]]; then
                echo "Ejecutando HISAT2 sobre $file y ${file%1.fq}2.fq como paired-end"
                hisat2 -x $refindex -1 ./fq/$file -2 ./fq/${file%1.fq}2.fq -S ./sam/${file%1.fq}.sam
            else
                echo "Ejecutando HISAT2 sobre $file en como SNGLE END"
                hisat2 -x $refindex -U ./fq/$file -S ./sam/${file%.fq}.sam
            fi
        fi
    done
    mkdir bam
    for file in $(ls ./sam)
    do
        echo "Check #2, entra en for, archivo: $file"
        if [[ $file == *.sam ]]; then
            echo "Ejecutando SAMTOOLS sobre $file en $(pwd)"
            samtools view -Sb ./sam/$file > ./bam/${file%.sam}.bam
        fi
    done
    mkdir sortbam
    for file in $(ls ./bam)
    do
        echo "Check 3, entra en for, archivo: $file"
        if [[ $file == *.bam ]]; then
            echo "Ejecutando SAMTOOLS sobre $file en $(pwd)"
            samtools sort ./bam/$file -o ./sortbam/sort-$file
        fi
    done
    if $2; then
        return 0
    fi
    for file in $(ls ./sortbam)
    do
        echo "Check #4, entra en for, archivo: $file"
        if [[ $file == sort*.bam ]]; then
            echo "Ejecutando SAMTOOLS sobre $file en $(pwd)"
            samtools index ./sortbam/$file
        fi
    done

    cuantos=0
    for file in $(ls)
    do
        if  [[ $file == *.g*f ]]; then
            cuantos=$cuantos+1
        fi
    done

#    if [[ $cuantos == 1 ]]; then
#        htseq-count -m union -t exon -f bam ./sortbam/*.bam *g*f > counts.txt
#    else
#        echo "ERROR: Existen $cuantos archivos GTF o GFF. Debe haber 1 (Archivo del genoma de referencia)"
#    fi
#    for file in $(ls)
#    do
#        echo "Check #5, entra en for, archivo: $file"
#        if [[ $file == *.gft ]] || [[ $file == *.gff ]]; then
#            echo "Convirtiendo $flie a formato BED"
#            samtools sort ./bam/$file -o ./sortbam/sort-$file #TODO
#            #ESTO NOS DA PROBLEMAS, AL DESCARGAR DE ENSEMBL Y OTROS
#        fi
#    done
}

testing() {
    for fileref in $(ls) #Busca ficheros gtf y fa
    do
        if [[ $fileref == *.gff ]] || [[ $fileref == *.gtf ]]; then
            gtf2bed < $fileref > output.bed #Escribir un check de RSeQC install
            break
        fi
    done
    for fileinput in $(ls ./sortbam/)
    do
        if [[ $fileinput == sort*.bam ]]; then
            infer_experiment.py -r $fileref -i $fileinput
            return "Test finalizado"
            break
        fi
    done
}

flagstat() {
    for file in $(ls ./sam) #Busca archivos
    do
        if [[ $file == *.sam ]]; then #Lo hacemos con los SAMS, chequear.
            echo "Analizando FLAGSTAT de $file"
            samtools flagstat ./sam/$file 
            echo "infer experiment de $file"
            infer_experiment.py -r new-bed-output.bed -i ./sam/$file
            return "Test finalizado"
        fi
    done
}

#Fin de funciones
mkdir extra
answer1=b
while true;
do
    echo "Do you know if your data is STRAND-SPECIFIC (stranded) or NOT-SPECIFIC (unstranded)?"
    echo "y: YES, I have that information"
    echo "n: NO, I do not have this information"
    echo "Type to [yes/no/cancel] as: [y/n/c]"
    read -n 1 answer1
    if [[ "ync" != *"$answer1"* ]]; then
    	continue
    elif [[ "y" == $answer1 ]]; then
        echo "Is it strand-specific (s), nonspecific (n) or go back (b)"
    	echo "Type [specific/nonspecific/back] as: [s/n/b]"
    	read -n 1 answer2
    	if [[ "s" == $answer2 ]]; then
        	specific=true
	    	break
        elif [[ "n" == $answer2 ]]; then
    	    specific=false
    	    break
        else
            answer1='b'
	    fi
    elif [[ "n" == $answer1 ]]; then
        echo "Do you want to run a test to check for strandedness [RECOMENDED] (if not, it will assume unstrandedness)"
    	echo "Type [yes/no/back] as: [y/n/b]"
        read -n 1 answer3
    	if [[ "y" == $answer3 ]]; then
        	runtest=true
        	break
        elif [[ "n" == $answer3 ]]; then
            runtest=false
            specific=false
	    	break
        else
            answer1='b'
	    fi
    elif [[ "c" == $answer1 ]]; then
        echo "EXITING program"
        exit 0
    fi
done
echo "User said y/n: $answer1 y el strand es specific: $specific, Se hará test: $runtest"

if [ ! -d "fq" ]; then
    if [ -d "fq-gz" ]; then
        mkdir fq
    	cp ./fq-gz/* ./fq
    	gunzip ./fq/*
    else
    	echo "ERROR, los directorios no están nombrados correctamente (deben haber un dir 'fq' o 'fq-gz')"
        exit 0
    fi
fi

for file in $(ls)
do
    if [[ $file == *.gz ]]; then
        cp $file ./extra
        gunzip $file
    fi
done

for file in $(ls) #Check de existencia de ficheros gtf y fa
do
    if [[ $file == *.gff ]] || [[ $file == *.gtf ]]; then
        gtfexist=true
    elif [[ $file == *.fa ]]; then
        faexist=true
    fi
done
if [[ $faexist != true ]] || [[ $gtfexist != true ]]; then
    echo "ERROR, no se detectan archivos .fa o (.gtf/.gff), ni sus comprimidos"
    exit 0
fi

#for file in $(ls) #Crear checks generales, si existe tal directorio no se ejecuta esto.
#do
#    if [[ $file == *.fa ]]; then
#        #hisat2-build $file ${file%.fa}_index
#        #refindex="$(pwd)/${file%.fa}_index"
#    fi
#done
refindex="/media/alexis/Backups/CEU-PRACTICAS/Plaquetas/GRCh38.primary_assembly.genome_index"

#OJO, ASUMIMOS que son paired-end.
pairend=true
if [[ $runtest == true ]]; then
    mkdir test
    mkdir ./test/fq #Selección de un par para el test
    for file in ./fq/*1.fq; do
        pair="${file%1.fq}2.fq" 
        #Check if the corresponding file exists
        if [ -e "${pair}" ]; then
            echo "Found pair: ${file} and ${pair}"
            cp $file $pair ./test/fq
            echo "TEST"
            cd ./test
            pipeline $pairend $runtest
            cd ..
            testing
            echo "$?"
            break
        fi
    done
else
    pipeline $pairend $runtest
    flagstat
fi