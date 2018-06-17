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
    -cs|--coversize)
    COVERSIZE="$2"
    shift # past argument
    shift # past value
    ;;
    -n|--normalize)
    NORMALIZE=YES
    shift # past argument
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

function help(){
echo """Music Manager script by Koboldo
This script is used for managing the audio files in a given folder.

Arguments:
-fo folder	Specifies the folder to work in.
-cs nnnxnnn	Specifies the cover size. Note that this is formatted as widthxheight.
-n		Normalizes the volume of all audio files in folder. Useful to give all files the same volume."""
}

if [ -z "${FOLDER}" ]; then
	help
	exit
fi

echo FOLDER		= "${FOLDER}"
echo COVERSIZE		= "${COVERSIZE}"
echo NORMALIZE		= "${NORMALIZE}"
#exit
#echo SEARCH PATH     = "${SEARCHPATH}"
#echo LIBRARY PATH    = "${LIBPATH}"
#echo DEFAULT         = "${DEFAULT}"
echo "Number of files to process:" $(ls -1 "${FOLDER}" | wc -l)
cd "${FOLDER}"
for file in *.mp3; do
	echo -------------------------
	if [ ! -z ${NORMALIZE} ] || [ ! -z ${COVERSIZE} ]; then
		echo "File: ""$file"
	fi
	if [ ! -z ${NORMALIZE} ]; then
		ffmpeg -i "$file" -af "volumedetect" -vn -sn -dn -f null /dev/null > temp.txt 2>&1
		#cat out.txt | grep n_samples
		#cat out.txt | grep mean_volume
		initialvolume=$(cat temp.txt | grep max_volume | cut -d : -f 2 | cut -c 2-20 | sed "s/ //g")
		echo "Initial volume: ""$initialvolume"
		firstdigit=$(echo $initialvolume | cut -c 1)
		if [ $firstdigit == "-" ]; then
			if [ $(echo $initialvolume | cut -c 2) -gt 0 ]; then
				echo "Changing volume..."
				finalvolume=$(echo "$initialvolume" | sed "s/-//g")
				ffmpeg -loglevel panic -i "$file" -af "volume=""$finalvolume" temp.mp3
				rm "$file"
				mv temp.mp3 "$file"
				ffmpeg -i "$file" -af "volumedetect" -vn -sn -dn -f null /dev/null > temp2.txt 2>&1
				volume=$(cat temp2.txt | grep max_volume | cut -d : -f 2 | cut -c 2-20 | sed "s/ //g")
				echo "Final volume: ""$volume"
				rm temp.txt temp2.txt
			else
				echo "Volume already at maximum, skipping"
			fi
		else
			if [ $(echo $initialvolume | cut -c 1) -gt 0 ]; then
				echo "Changing volume..."
				finalvolume="-"$initialvolume
				ffmpeg -loglevel panic -i "$file" -af "volume=""$finalvolume" temp.mp3
				rm "$file"
				mv temp.mp3 "$file"
				ffmpeg -i "$file" -af "volumedetect" -vn -sn -dn -f null /dev/null > temp2.txt 2>&1
				volume=$(cat temp2.txt | grep max_volume | cut -d : -f 2 | cut -c 2-20 | sed "s/ //g")
				echo "Final volume: ""$volume"
				rm temp.txt temp2.txt
			else
				echo "Volume already at maximum, skipping"
			fi
		fi
		#echo -------------------------
	fi
	if [ ! -z ${COVERSIZE} ]; then
		ffmpeg -loglevel panic -i "$file" -an -vcodec copy "$file".jpg
		initialcoverwidth=$(identify -format "%w" "$file"".jpg")
		initialcoverheight=$(identify -format "%h" "$file"".jpg")
		if [ "$initialcoverwidth""x""$initialcoverheight" != "${COVERSIZE}" ]; then
			echo "The cover size is: " $initialcoverwidth"x"$initialcoverheight", resizing..."
			convert "$file"".jpg" -resize "${COVERSIZE}" "$file""_resized.jpg"
			echo "Adding resized cover..."
			ffmpeg -loglevel panic -i "$file" -i "$file""_resized.jpg" -map 0:0 -map 1:0 -c copy -id3v2_version 3 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (Front)" temp2.mp3
			rm "$file" "$file""_resized.jpg"
			mv temp2.mp3 "$file"
		else
			echo "The cover is already at the selected size, skipping..."
		fi
		rm "$file".jpg
		#echo -------------------------
	fi
done
cd ..


if [[ -n $1 ]]; then
    echo "Last line of file specified as non-opt/last argument:"
    tail -1 "$1"
fi