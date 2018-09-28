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
    -ic|--insertcover)
    INSERTCOVER="$2"
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


## Funcions declaration ##

function help(){
echo """Music Manager script by Koboldo
This script is used for managing the audio files in a given folder.

Arguments:
-fo folder	Specifies the folder to work in.
-cs nnnxnnn	Specifies the cover size. Note that this is formatted as widthxheight.
-ic image	Inserts a cover from the image given.
-n		Normalizes the volume of all audio files in folder. Useful to give all files the same volume."""
}



function normalize {
	ffmpeg -i "$1" -af "volumedetect" -vn -sn -dn -f null /dev/null > temp.txt 2>&1
	initialvolume=$(cat temp.txt | grep max_volume | cut -d : -f 2 | cut -c 2-20 | sed "s/ //g")
	echo "Initial volume: ""$initialvolume"
	firstdigit=$(echo $initialvolume | cut -c 1)
	if [ $firstdigit == "-" ]; then
		if [ $(echo $initialvolume | cut -c 2) -gt 0 ]; then
			echo "Changing volume..."
			finalvolume=$(echo "$initialvolume" | sed "s/-//g")
			ffmpeg -loglevel panic -i "$1" -af "volume=""$finalvolume" temp.mp3
			rm "$1"
			mv temp.mp3 "$1"
			ffmpeg -i "$1" -af "volumedetect" -vn -sn -dn -f null /dev/null > temp2.txt 2>&1
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
			ffmpeg -loglevel panic -i "$1" -af "volume=""$finalvolume" temp.mp3
			rm "$1"
			mv temp.mp3 "$1"
			ffmpeg -i "$1" -af "volumedetect" -vn -sn -dn -f null /dev/null > temp2.txt 2>&1
			volume=$(cat temp2.txt | grep max_volume | cut -d : -f 2 | cut -c 2-20 | sed "s/ //g")
			echo "Final volume: ""$volume"
			rm temp.txt temp2.txt
		else
			echo "Volume already at maximum, skipping"
		fi
	fi
}

function coversize {
	ffmpeg -loglevel panic -i "$1" -an -vcodec copy "$1".jpg
	initialcoverwidth=$(identify -format "%w" "$1"".jpg")
	initialcoverheight=$(identify -format "%h" "$1"".jpg")
	if [ "$initialcoverwidth""x""$initialcoverheight" != "${COVERSIZE}" ]; then
		echo "The cover size is: " $initialcoverwidth"x"$initialcoverheight", resizing..."
		convert "$1"".jpg" -resize "${COVERSIZE}" "$1""_resized.jpg"
		echo "Adding resized cover..."
		ffmpeg -loglevel panic -i "$1" -i "$1""_resized.jpg" -map 0:0 -map 1:0 -c copy -id3v2_version 3 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (Front)" temp2.mp3
		rm "$1" "$1""_resized.jpg"
		mv temp2.mp3 "$1"
	else
		echo "The cover is already at the selected size, skipping..."
	fi
	rm "$1".jpg
}

function insertcover {
	echo "Removing previous album art..."
	ffmpeg -loglevel panic -i "$file" -map 0:a -codec:a copy -map_metadata -1 audio.mp3
	echo "Inserting new album art..."
	rm "$file"
	ffmpeg -loglevel panic -i audio.mp3 -i "${INSERTCOVER}" -map 0:0 -map 1:0 -c copy -id3v2_version 3 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (Front)" "$file"
	rm audio.mp3
}


## Start working ##

if [ -z "${FOLDER}" ]; then
	help
	exit
fi

echo FOLDER		= "${FOLDER}"
echo COVERSIZE		= "${COVERSIZE}"
echo INSERTCOVER	= "${INSERTCOVER}"
echo NORMALIZE		= "${NORMALIZE}"

echo "Number of files to process:" $(ls -1 "${FOLDER}" | wc -l)

cd "${FOLDER}"

if [ ! -z ${NORMALIZE} ]; then
	echo
	echo "Normalizing files..."
	echo "---------------------------------"
	for file in *.mp3; do
		echo "File: ""$file"		
		normalize "$file"
		echo
	done
	echo
fi

if [ ! -z ${INSERTCOVER} ]; then
	echo
	echo "Inserting album covers..."
	echo "---------------------------------"
	for file in *.mp3; do
		echo "File: ""$file"
		insertcover "$file"
		echo
	done
	echo
fi

if [ ! -z ${COVERSIZE} ]; then
	echo
	echo "Changing album covers sizes..."
	echo "---------------------------------"
	for file in *.mp3; do
		echo "File: ""$file"		
		coversize "$file"
		echo
	done
	echo
fi

cd ..


if [[ -n $1 ]]; then
    echo "Last line of file specified as non-opt/last argument:"
    tail -1 "$1"
fi