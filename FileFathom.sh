#!/bin/bash

# Funzione per mostrare l'uso corretto dello script
show_banner() {
    cat << "EOF"
 _____  ____  _        ___  _____   ____  ______  __ __   ___   ___ ___     
|     ||    || |      /  _]|     | /    ||      ||  |  | /   \ |   |   |    
|   __| |  | | |     /  [_ |   __||  o  ||      ||  |  ||     || _   _ |    
|  |_   |  | | |___ |    _]|  |_  |     ||_|  |_||  _  ||  O  ||  \_/  |    
|   _]  |  | |     ||   [_ |   _] |  _  |  |  |  |  |  ||     ||   |   |    
|  |    |  | |     ||     ||  |   |  |  |  |  |  |  |  ||     ||   |   |    
|__|   |____||_____||_____||__|   |__|__|  |__|  |__|__| \___/ |___|___|    
                                                                            
EOF
}

# Mostra il banner
show_banner

usage() {
    echo "Usage: $0 -f <file> [-o <output_file>] [-s] [-x] [-a] [-l <num_bytes>] [-h] [-t]"
    echo "  -f <file>           Specify the file to analyze"
    echo "  -o <output_file>    Specify the output file"
    echo "  -s                  Extract strings from the file"
    echo "  -x                  Display hex dump of the file"
    echo "  -a                  Analyze sections of the file"
    echo "  -l <num_bytes>      Number of bytes to display in hex dump (default: 256)"
    echo "  -h                  Show this help message"
    echo "  -t                  Try to identify the type of file"
    exit 1
}

# Valore predefinito per il numero di byte da visualizzare nel dump esadecimale
hex_dump_length=256

# Inizializzazione delle variabili di flag a false
extract_strings_flag=false
analyze_sections_flag=false
hex_dump_flag=false
output_flag=false
try_identify_flag=false
mn4=false

# Parsing delle opzioni della linea di comando
while getopts ":f:o:sxtal:h" opt; do
    case ${opt} in
        f )
            file=$OPTARG
            ;;
        o )
            output_flag=true
            outp=$OPTARG
            ;;
        s )
            extract_strings_flag=true
            ;;
        x )
            hex_dump_flag=true
            ;;
        t )
            try_identify_flag=true
            ;;
        a )
            analyze_sections_flag=true
            ;;
        l )
            hex_dump_length=$OPTARG
            ;;
        h )
            usage
            ;;
        \? )
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
        : )
            echo "Option -$OPTARG requires an argument." >&2
            usage
            ;;
    esac
done

if [ "$extract_strings_flag" = false ] && [ "$analyze_sections_flag" = false ] && [ "$hex_dump_flag" = false ] && [ "$try_identify_flag" = false ]; then
    usage
    exit 1
fi

# Verifica che il file sia specificato
if [ -z "$file" ]; then
    usage
fi

# Verifica che il file esista
if [ ! -f "$file" ]; then
    echo "File not found: $file"
    exit 1
fi

# Verifica e crea il file di output se specificato
if [ -n "$outp" ]; then
    if [ -f "$outp" ]; then
        > "$outp"  # Cancella il contenuto del file esistente
    else
        touch "$outp"  # Crea il file se non esiste
    fi
else
    outp="/dev/stdout"
fi

echo "File to analyze: $file" >> "$outp"
echo >> "$outp"

# Eseguire le funzioni in base alle flag impostate
if [ "$extract_strings_flag" = true ]; then
    echo "Extracting strings from $file..." >> "$outp"
    strings "$file" >> "$outp"
    echo >> "$outp"
    extract_strings_flag=false
fi

if [ "$analyze_sections_flag" = true ]; then
    echo "Analyzing sections of $file..." >> "$outp"
    objdump -h "$file" >> "$outp"
    echo >> "$outp"
    analyze_sections_flag=false
fi

if [ "$hex_dump_flag" = true ]; then
    echo "Hex dump of $file (first $hex_dump_length bytes)..." >> "$outp"
    xxd -l "$hex_dump_length" "$file" >> "$outp"
    echo >> "$outp"
    hex_dump_flag=false
fi

if [ "$try_identify_flag" = true ]; then
    magic_number_8=$(xxd -l 8 -p "$file" | tr -d '\n')
    magic_number_4=${magic_number_8:0:4}

    case "$magic_number_4" in
        "4d5a") # Magic number per file eseguibile Windows (MZ)
            echo "File is a Windows executable." >> "$outp"
            mn4=true
            ;;
    esac
    echo > "$outp"

    if [ "$mn4" = false ]; then
        case "${magic_number_8:0:8}" in
            "7f454c46") # Magic number per file eseguibile ELF (Linux/Unix)
                echo "File is a Linux/Unix ELF executable." >> "$outp"
                ;;
            "ffd8ffe0" | "ffd8ffe1" | "ffd8ffe2") # Magic number per file JPEG
                echo "File is a JPEG image." >> "$outp"
                ;;
            "89504e47") # Magic number per file PNG
                echo "File is a PNG image." >> "$outp"
                ;;
            "47494638") # Magic number per file GIF
                echo "File is a GIF image." >> "$outp"
                ;;
            "25504446") # Magic number per file PDF
                echo "File is a PDF document." >> "$outp"
                ;;
            "504b0304") # Magic number per file ZIP e file di Office basati su OpenXML
                # Dobbiamo verificare ulteriormente per determinare il tipo specifico di file
                if zipgrep -q "word/" "$file"; then
                    echo "File is a Microsoft Word document (DOCX)." >> "$outp"
                elif zipgrep -q "ppt/" "$file"; then
                    echo "File is a Microsoft PowerPoint document (PPTX)." >> "$outp"
                elif zipgrep -q "xl/" "$file"; then
                    if zipgrep -q "vbaProject.bin" "$file"; then
                        echo "File is a Microsoft Excel Macro-Enabled Workbook (XLSM)." >> "$outp"
                    else
                        echo "File is a Microsoft Excel Workbook (XLSX)." >> "$outp"
                    fi
                else
                    echo "File is a ZIP archive." >> "$outp"
                fi
                ;;
            "d0cf11e0") # Magic number per file DOC/XLS/PPT (OLE2)
                echo "File is a Microsoft Office document (OLE2)." >> "$outp"
                ;;
            "1f8b0800") # Magic number per file GZIP
                echo "File is a GZIP archive." >> "$outp"
                ;;
            "424d") # Magic number per file BMP
                echo "File is a BMP image." >> "$outp"
                ;;
            "3c3f786d") # Magic number per file XML
                echo "File is an XML document." >> "$outp"
                ;;
            "75737461") # Magic number per file TAR
                echo "File is a TAR archive." >> "$outp"
                ;;
            "3026b275") # Magic number per file ASF/WMV/WMA
                echo "File is an ASF/WMV/WMA media file." >> "$outp"
                ;;
            "664c6143") # Magic number per file FLAC
                echo "File is a FLAC audio file." >> "$outp"
                ;;
            "4f676753") # Magic number per file OGG
                echo "File is an OGG media file." >> "$outp"
                ;;
            "377abcaf") # Magic number per file 7z
                echo "File is a 7z archive." >> "$outp"
                ;;
            "7b5c7274") # Magic number per file RTF
                echo "File is an RTF document." >> "$outp"
                ;;
            "3c21444f") # Magic number per file HTML
                echo "File is an HTML document." >> "$outp"
                ;;
            "cafebabe") # Magic number per file Java class
                echo "File is a Java class file." >> "$outp"
                ;;
            "52656435") # Magic number per file RealMedia
                echo "File is a RealMedia file." >> "$outp"
                ;;
            "41433130") # Magic number per file DWG (AutoCAD)
                echo "File is an AutoCAD drawing file." >> "$outp"
                ;;
            "1a45dfa3") # Magic number per file Matroska (MKV)
                echo "File is a Matroska media file." >> "$outp"
                ;;
            "25215053") # Magic number per file PostScript
                echo "File is a PostScript document." >> "$outp"
                ;;
            "464c5601") # Magic number per file FLV (Flash Video)
                echo "File is a Flash Video file." >> "$outp"
                ;;
            "3c68746d" | "3c48544d") # Magic number per file HTML (alternative)
                echo "File is an HTML document." >> "$outp"
                ;;
            "000001ba") # Magic number per file MPEG-PS
                echo "File is an MPEG Program Stream file." >> "$outp"
                ;;
            "000001b3") # Magic number per file MPEG
                echo "File is an MPEG file." >> "$outp"
                ;;
            "49443303") # Magic number per file MP3
                echo "File is an MP3 audio file." >> "$outp"
                ;;
            "425a6839") # Magic number per file BZIP2
                echo "File is a BZIP2 compressed file." >> "$outp"
                ;;
            *)
                echo "Unknown file type." >> "$outp"
                ;;
        esac
        echo > "$outp"
    fi
    try_identify_flag=false
fi