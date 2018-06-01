#!/bin/bash

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -fo|--folder)
    FOLDER="$2"
    shift # past argument
    shift # past value
    ;;
    -s|--searchpath)
    SEARCHPATH="$2"
    shift # past argument
    shift # past value
    ;;
    -l|--lib)
    LIBPATH="$2"
    shift # past argument
    shift # past value
    ;;
    --default)
    DEFAULT=YES
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

echo FOLDER		= "${FOLDER}"
#echo SEARCH PATH     = "${SEARCHPATH}"
#echo LIBRARY PATH    = "${LIBPATH}"
#echo DEFAULT         = "${DEFAULT}"
echo "Number of files to process:" $(ls -1 "${FOLDER}" | wc -l)
echo -------------------------
cd ${FOLDER}
for file in *.mp3; do
	echo "File: ""$file"
	ffmpeg -i "$file" -af "volumedetect" -vn -sn -dn -f null /dev/null > temp.txt 2>&1
	#cat out.txt | grep n_samples
	#cat out.txt | grep mean_volume
	initialvolume=$(cat temp.txt | grep max_volume | cut -d : -f 2 | cut -c 2-20 | sed "s/ //g")
	echo "Initial volume: ""$initialvolume"
	number=$(echo "$initialvolume" | sed "s/dB//g")
	finalvolume=$(echo ""$number"*(-1)" | bc)
	if [ $finalvolume != 0 ]; then
		echo "Changing volume..."
		ffmpeg -loglevel panic -i "$file" -af "volume=""$finalvolume""dB" temp.mp3
		rm "$file"
		mv temp.mp3 "$file"
		ffmpeg -i "$file" -af "volumedetect" -vn -sn -dn -f null /dev/null > temp2.txt 2>&1
		volume=$(cat temp2.txt | grep max_volume | cut -d : -f 2 | cut -c 2-20 | sed "s/ //g")
		echo "Final volume: ""$volume"
		rm temp.txt temp2.txt
	else
		echo "Volume already at maximum, skipping"
	fi
	echo -------------------------
done
cd ..


if [[ -n $1 ]]; then
    echo "Last line of file specified as non-opt/last argument:"
    tail -1 "$1"
fi