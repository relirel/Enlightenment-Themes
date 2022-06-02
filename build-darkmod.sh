#!/bin/bash
#####################################################################
#                                                                   #
# darkmod - Enlightenment Dark theme modifier                       #
#                                                                   #
#   You should not modify this file directly all colors and paths   #
#   can be modified in darkmod-colors-paths.sh images that you      #
#   wish to modify manually can be placed in the img-manual         #
#   directory and they will be included over the existing images    #
#                                                                   #
#####################################################################
if [[ $1 == '--epkg' ]]; then
    DKMD_EPKG=1
else
    DKMD_EPKG=0
fi

if [[ $1 == '--termpkg' ]]; then
    DKMD_TERMPKG=1
else
    DKMD_TERMPKG=0
fi

hash edje_cc 2>/dev/null || { echo >&2 "I require edje_cc but it's not installed.  Aborting."; exit 1; }
hash convert 2>/dev/null || { echo >&2 "I require the convert binary from imagemagick but it's not installed.  Aborting."; exit 1; }

# load libraries
source darkmod-color-paths.conf
source darkmod-util.sh
source darkmod-copy.sh
source clean-darkmod.sh


# Other modifications
# battery.edc
# about-theme.edc
# dark rounded rect needs to be light
# filemanager icons
# menu text
# load from param
# everything shadows

inform "Cleaning Repository"
clean-darkmod $THEME_NAME
success "    Finished Cleaning Repository"

if [[ $DKMD_TERMPKG != 1 ]]; then
inform "Creating a backup of all images"
mkdir $ELM_ENLIGHT_THEME_PATH/img-bak
mkdir $ELM_ENLIGHT_THEME_PATH/img-manual-bak
mkdir $ELM_ENLIGHT_THEME_PATH/fdo-bak
report_on_error cp -vr $ELM_ENLIGHT_THEME_PATH/img/* $ELM_ENLIGHT_THEME_PATH/img-bak
if [[ -f $ELM_ENLIGHT_THEME_PATH/$MANUAL_IMAGE_CONVD_DIR/$1 ]]; then
  report_on_error cp -vr $ELM_ENLIGHT_THEME_PATH/img-manual-convd/* $ELM_ENLIGHT_THEME_PATH/img-manual-bak
fi
report_on_error cp -vr $ELM_ENLIGHT_THEME_PATH/fdo/* $ELM_ENLIGHT_THEME_PATH/fdo-bak
success "    Finished Creating Backup"


inform "Moving images to be converted"
moveAllHighlightImages
moveAllBackgroundImages
moveAllShadowImages
success "    Finished Moving images that need converting"


inform "Moving images that need no conversion"
mv $ELM_ENLIGHT_THEME_PATH/img $ELM_ENLIGHT_THEME_PATH/img-no-change
success "    Finished Moving images that don't need converting"

mkdir $ELM_ENLIGHT_THEME_PATH/img-color-convd

inform "Converting images"
pushd $ELM_ENLIGHT_THEME_PATH/img-color &> /dev/null
for F in `find -iname "*.png"`; do
        convert $F -modulate $HIGH_BRIGHTNESS,$HIGH_SATURATION,$HIGH_HUE ../img-color-convd/$F
done
popd &> /dev/null

HIGH_RAW=$(convert $ELM_ENLIGHT_THEME_PATH/img-color-convd/bg_glow_in.png -crop "1x1+0+0" txt:-)
#HIGH_HTML=$HIGH_RAW | sed -n 's/.*\(*#[0-9][0-9][0-9][0-9][0-9][0-9]*\).*/\1/p'
#remove most of the variable content
TMP_MID=$(echo "$HIGH_RAW"| cut -d "#" -f2)
#remove the remaining fixed content
TMP_EXTRACTED=${TMP_MID#${TMP_MID:0:46}}
#form the html number
HIGH_HTML="#${TMP_EXTRACTED:0:6}"
#form the rgb number

HIGH_HTML=$(convert $ELM_ENLIGHT_THEME_PATH/img-color-convd/bg_glow_in.png -crop "1x1+0+0" txt:- | awk 'match($0, /#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/) {print substr($0, RSTART, RLENGTH)}')

# Need the first bracket to match the right string so remove it after
HIGH_RGB=$(convert $ELM_ENLIGHT_THEME_PATH/img-color-convd/bg_glow_in.png -crop "1x1+0+0" txt:- | perl -e 'while(<STDIN>){if(/srgba\((\d+),(\d+),(\d+)/){print"$1,$2,$3\n"}}')
# Substitute , for " "
HIGH_RGB=$(echo "$HIGH_RGB" | tr "," " ")

set $HIGH_RGB
HIGH_RED=$1
HIGH_GREEN=$2
HIGH_BLUE=$3

#if we don't have a valid color error
if [[ -z "$HIGH_HTML" ]]; then
    error "Highlight Color could not be determined"
    # Move images back before exit
    report_on_error mv -v img-bak img
    report_on_error mv -v img-manual-bak/* img-manual-convd
    exit 1
fi
if [[ -z "$HIGH_RGB" ]]; then
    error "Highlight Color could not be determined"
    # Move images back before exit
    report_on_error mv -v img-bak img
    report_on_error mv -v img-manual-bak/* img-manual-convd
    exit 1
fi

if [[ -d "$ELM_ENLIGHT_THEME_PATH/img-color-manual" ]]; then
    pushd $ELM_ENLIGHT_THEME_PATH/img-color-manual &> /dev/null
    for F in `find -iname "*.png"`; do
            convert $F -modulate $HIGH_BRIGHTNESS,$HIGH_SATURATION,$HIGH_HUE ../img-color-convd/$F
    done
    popd &> /dev/null
fi

# Converting background images
pushd $ELM_ENLIGHT_THEME_PATH/img-bgnd &> /dev/null
for F in `find -iname "*.png"`; do
    convert $F -channel rgb -brightness-contrast $BGND_BRIGHTNESS,$BGND_SATURATION +channel ../img-color-convd/$F
done
popd &> /dev/null

#converting shadows
pushd $ELM_ENLIGHT_THEME_PATH/img-shadow &> /dev/null
for F in `find -iname "*.png"`; do
    convert $F -channel A -evaluate Multiply $SHADOW_MULT ../img-color-convd/$F
    # convert $F -channel A -evaluate set 20% ../img-color-convd/$F
    # cp $F ../img-color-convd/$F
done
popd &> /dev/null

inform "Recoloring FDO icons"
# Recolor the fdo icon theme
for icon in $(cat darkmod-fdo-icon-recolor.txt); do
  for F in `find $ELM_ENLIGHT_THEME_PATH/fdo -name "$icon.svg"`; do
    sed -i "s/#3399ff/$HIGH_HTML/g" $F
  done
  for F in `find $ELM_ENLIGHT_THEME_PATH/fdo -name "$icon.png"`; do
    convert $F -modulate $HIGH_BRIGHTNESS,$HIGH_SATURATION,$HIGH_HUE $F
  done
done

mkdir -p "build/icons/"
clean_dir build/icons/$THEME_NAME-icons
cp -r $ELM_ENLIGHT_THEME_PATH/fdo build/icons/$THEME_NAME-icons
sed -i "s/Enlightenment-X/$THEME_NAME-e-X/g" "build/icons/$THEME_NAME-icons/index.theme"


success "    Finished Converting Images"

inform "Rewriting .edc"
pushd $ELM_ENLIGHT_THEME_PATH &> /dev/null
report_on_error cp -a edc edc-dm

report_on_error cp -a colorclasses.edc colorclasses-dm.edc
report_on_error cp -a fonts.edc fonts-dm.edc
report_on_error cp -a macros.edc macros-dm.edc

# Figure out which images exist (todo separate this)
echo "/* This is a generated file do not edit */" > generated-defns-dm.edc

if [[ -f "img-manual/menu_background.png" ]]; then
    echo "#define VTX_MENU_BACKGROUND 1" >> generated-defns-dm.edc
fi
if [[ -f "img-manual/menu_selected.png" ]]; then
    echo "#define VTX_MENU_SELECTED 1" >> generated-defns-dm.edc
fi
if [[ -f "img-manual/shelf_background_bottom.png" &&
      -f "img-manual/shelf_background_left.png" &&
      -f "img-manual/shelf_background_right.png" &&
      -f "img-manual/shelf_background_top.png" ]]; then
    echo "#define VTX_SHELF_MULIT 1" >> generated-defns-dm.edc
elif [[ -f "img-manual/shelf_background.png" ]]; then
    echo "#define VTX_SHELF_SINGLE 1" >> generated-defns-dm.edc
fi
if [[ -f "img-manual/shelf_entry.png" ]]; then
    echo "#define VTX_SHELF_ENTRY 1" >> generated-defns-dm.edc
fi

# Replace background and highlights in edc
for F in `find edc-dm colorclasses-dm.edc macros-dm.edc -iname "*.edc"`; do
    # Highlight color
    if [[ "$HIGH_RGB" != "51 153 255" ]]; then
        sed -i "s/51 153 255/$HIGH_RGB/g" $F
        sed -i "s/#3399ff/$HIGH_HTML/g" $F
        # for battery
        sed -i "s/r = 51, g = 153, b = 255/r = $HIGH_RED, g = $HIGH_GREEN, b = $HIGH_BLUE/g" $F
    fi

    # File manager background
    if [[ "$FILEMGR_BKND_RGB" != "64 64 64" ]]; then
        sed -i "s/64 64 64/$FILEMGR_BKND_RGB/g" $F
        sed -i "s/#404040/$FILEMGR_BKND_HTML/g" $F
    fi

    # file manager alt
    if [[ "$FILEMGR_ALT_BKND_RGB" != "56 56 56" ]]; then
        sed -i "s/56 56 56/$FILEMGR_ALT_BKND_RGB/g" $F
        sed -i "s/#383838/$FILEMGR_ALT_BKND_HTML/g" $F
    fi

    # File manager image background
    if [[ "$FILEMGR_IMG_BKND_RGB" != "48 48 48" ]]; then
        sed -i "s/48 48 48/$FILEMGR_IMG_BKND_RGB/g" $F
        sed -i "s/#303030/$FILEMGR_IMG_BKND_HTML/g" $F
    fi

    # Grey boxes in pager
    if [[ "$FILEMGR_MID_GREY_RGB" != "50 50 50" ]]; then
        sed -i "s/50 50 50/$FILEMGR_MID_GREY_RGB/g" $F
        sed -i "s/#323232/$FILEMGR_MID_GREY_HTML/g" $F
    fi

    # Checkbox background (mostly for toggle)
    if [[ "$TOGGLE_BKND_RGB" != "24 24 24" ]]; then
        sed -i "s/24 24 24/$TOGGLE_BKND_RGB/g" $F
        sed -i "s/#181818/$TOGGLE_BKND_HTML/g" $F
    fi

    # modify html versions of text for textblock
    if [[ "$FNT_DEFAULT_HTML" != "#FFFFFF" ]]; then
        sed -i "s/#ffffff/$FNT_DEFAULT_HTML/gI" $F
        sed -i "s/#ffff/$FNT_DEFAULT_HTML/gI" $F
    fi

    if [[ "$FNT_DEFAULT_SHADOW_HTML" != "#00000080" ]]; then
        sed -i "s/#00000080/$FNT_DEFAULT_SHADOW_HTML/gI" $F
    fi

    # Disabled text
    if [[ "$FNT_DISABLED_HTML" != "#151515" ]]; then
        sed -i "s/#151515/$FNT_DISABLED_HTML/g" $F
    fi

    if [[ "$FNT_DISABLED_SHADOW_HTML" != "#FFFFFF19" ]]; then
        sed -i "s/#FFFFFF19/$FNT_DISABLED_SHADOW_HTML/gI" $F
    fi
done

# replace text colors / yes this probably doesn't need a for loop
for F in `find fonts-dm.edc -iname "*.edc"`; do
    # default text
    if [[ "$FNT_DEFAULT_RGB" != "255 255 255" ]]; then
        sed -i "s/255 255 255/$FNT_DEFAULT_RGB/g" $F
        sed -i "s/#ffffff/$FNT_DEFAULT_HTML/gI" $F
        sed -i "s/#ffff/$FNT_DEFAULT_HTML/gI" $F
    fi

    if [[ "$FNT_DEFAULT_SHADOW_RGB" != "0 0 0 128" ]]; then
        sed -i "s/0 0 0 128/$FNT_DEFAULT_SHADOW_RGB/g" $F
        sed -i "s/#00000080/$FNT_DEFAULT_SHADOW_HTML/gI" $F
    fi

    # Highlight color
    if [[ "$HIGH_RGB" != "51 153 255" ]]; then
        sed -i "s/51 153 255/$HIGH_RGB/g" $F
        sed -i "s/#3399ff/$HIGH_HTML/g" $F
    fi

    # Disabled text
    if [[ "$FNT_DISABLED_HTM" != "#151515" ]]; then
        sed -i "s/21 21 21/$FNT_DISABLED_RGB/g" $F
        sed -i "s/16 16 16 16/16 $FNT_DISABLED_RGB/g" $F
        sed -i "s/#151515/$FNT_DISABLED_HTML/g" $F
    fi

    if [[ "$FNT_DISABLED_SHADOW_RG" != "255 255 255 25" ]]; then
        sed -i "s/255 255 255 25\ns/$FNT_DISABLED_SHADOW_RGB\n/g " $F
        sed -i "s/#FFFFFF19/$FNT_DISABLED_SHADOW_HTML/gI" $F
    fi

    # Various Grey text need 4 colors so it doesn't overwrite the name instead
    sed -i "s/192 192 192 192/192 $FNT_GREY_192_RGB/g" $F
    sed -i "s/172 172 172 172/172 $FNT_GREY_172_RGB/g" $F
    sed -i "s/152 152 152 152/152 $FNT_GREY_152_RGB/g" $F

done

sed -i "s/Dark/$THEME_NAME/g" edc-dm/about-theme.edc
sed -i "s/The default theme for Enlightenment/$THEME_DESC/g" edc-dm/about-theme.edc


# #repair the definition of blue - used in startup leds
report_on_error sed -i 's/#define BLUE    152 205 87 255/#define BLUE    51 153 255 255/' edc-dm/init.edc

report_on_error cp -a default.edc default-dm.edc

report_on_error sed -i 's/"edc/"edc-dm/' default-dm.edc
report_on_error sed -i 's/"colorclasses/"colorclasses-dm/' default-dm.edc
report_on_error sed -i 's/"fonts/"fonts-dm/' default-dm.edc
report_on_error sed -i 's/"macros/"macros-dm/' default-dm.edc
success "    Finished Writing .edc"


inform "Creating theme"
mkdir -p ../build/e
edje_cc -v -id $MANUAL_IMAGE_DIR -id img-color-convd -id img-no-change -fd fnt -sd snd default-dm.edc $ELM_ENLIGHT_AUTHORS $ELM_ENLIGHT_LICENSE ../build/e/$THEME_NAME.edj

report_on_error mv -v img-bak img
if [ -f $ELM_ENLIGHT_THEME_PATH/$MANUAL_IMAGE_CONVD_DIR/$1 ]; then
  report_on_error mv -v img-manual-bak/* img-manual-convd
fi
clean_dir fdo
report_on_error mv -v fdo-bak fdo
if [[ -f ../build/e/$THEME_NAME.edj ]]; then
  mkdir -p "../artifacts/bin-e"
  cp "../build/e/$THEME_NAME.edj" "../artifacts/bin-e/"
  if [[ $DKMD_EPKG != 1 && $DKMD_TERMPKG != 1 ]]; then
    report_on_error install ../build/e/$THEME_NAME.edj ~/.elementary/themes
    inform "Compressing Icon Theme"
    mkdir -p ../artifacts/icons/
    pushd ../build/icons/ &> /dev/null
    report_on_error tar -cf "../../artifacts/icons/$THEME_NAME-$THEME_VERSION-icons.tar.xz" "$THEME_NAME-icons/"
    popd &> /dev/null
    inform "" # Lazy new line
    inform "Enlightenment Theme Complete"
    inform "" # Lazy new line
  fi
else
  error "build probably failed exiting"
  exit 1
fi
popd &> /dev/null

fi

##############################################################################################################################

termColorschemes=("$THEME_NAME.eet")

if [[ -n "$TERMINOLOGY_THEME_PATH" ]];then
if [[ $DKMD_EPKG != 1 ]]; then

    mkdir $TERMINOLOGY_THEME_PATH/img-bak
    report_on_error cp -vr $TERMINOLOGY_THEME_PATH/images/* $TERMINOLOGY_THEME_PATH/img-bak

    moveAllTerminologyHighlightImages
    moveAllTerminologyBackgroundImages
    moveAllTerminologyShadowImages

    mv $TERMINOLOGY_THEME_PATH/images $TERMINOLOGY_THEME_PATH/img-no-change
    success "    Finished moving terminology images"

    mkdir $TERMINOLOGY_THEME_PATH/img-color-convd

    pushd $TERMINOLOGY_THEME_PATH/img-color &> /dev/null
    for F in `find -iname "*.png"`; do
            convert $F -modulate $HIGH_BRIGHTNESS,$HIGH_SATURATION,$HIGH_HUE ../img-color-convd/$F
    done
    popd &> /dev/null

    if [[ -d "$TERMINOLOGY_THEME_PATH/img-color-manual" ]]; then
        pushd $TERMINOLOGY_THEME_PATH/img-color-manual &> /dev/null
            for F in `find -iname "*.png"`; do
                    convert $F -modulate $HIGH_BRIGHTNESS,$HIGH_SATURATION,$HIGH_HUE ../img-color-convd/$F
            done
        popd &> /dev/null
    fi

    # Converting background images
    pushd $TERMINOLOGY_THEME_PATH/img-bgnd &> /dev/null
    for F in `find -iname "*.png"`; do
        convert $F -brightness-contrast $BGND_BRIGHTNESS,$BGND_SATURATION ../img-color-convd/$F
    done
    popd &> /dev/null

    #converting shadows
    pushd $TERMINOLOGY_THEME_PATH/img-shadow &> /dev/null
    for F in `find -iname "*.png"`; do
        convert $F -channel A -evaluate Multiply $SHADOW_MULT ../img-color-convd/$F
    done
    popd &> /dev/null

    if [[ $DKMD_TERMPKG == 1 ]]; then
    	HIGH_RAW=$(convert $TERMINOLOGY_THEME_PATH/img-color-convd/bg_glow_in.png -crop "1x1+0+0" txt:-)
    	#HIGH_HTML=$HIGH_RAW | sed -n 's/.*\(*#[0-9][0-9][0-9][0-9][0-9][0-9]*\).*/\1/p'
    	#remove most of the variable content
    	TMP_MID=$(echo "$HIGH_RAW"| cut -d "#" -f2)
    	#remove the remaining fixed content
    	TMP_EXTRACTED=${TMP_MID#${TMP_MID:0:46}}
    	#form the html number
    	HIGH_HTML="#${TMP_EXTRACTED:0:6}"

    	HIGH_HTML=$(convert $TERMINOLOGY_THEME_PATH/img-color-convd/bg_glow_in.png -crop "1x1+0+0" txt:- | awk 'match($0, /#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/) {print substr($0, RSTART, RLENGTH)}')
    	#form the rgb number
    	# Need the first bracket to match the right string so remove it after
    	HIGH_RGB=$(convert $TERMINOLOGY_THEME_PATH/img-color-convd/bg_glow_in.png -crop "1x1+0+0" txt:- | perl -e 'while(<STDIN>){if(/srgba\((\d+),(\d+),(\d+)/){print"$1,$2,$3\n"}}')
    	# Substitute , for " "
    	HIGH_RGB=$(echo "$HIGH_RGB" | tr "," " ")
   fi

   # Convert theme svg Images
   pushd $TERMINOLOGY_THEME_PATH/img-color &> /dev/null
   for F in `find . -iname "*.svg"`; do
     sed "s/#3399ff/$HIGH_HTML/g" $F > ../img-color-convd/$F
   done
   popd &> /dev/null

    pushd $TERMINOLOGY_THEME_PATH &> /dev/null
    report_on_error cp -a default.edc default-dm.edc
    report_on_error cp -a Default.ini Default-dm.ini
    report_on_error sed -i "s/"default/"default-dm/" default-dm.edc

    report_on_error cp -a default default-dm

    # Replace background and highlights in edc
    for F in `find default-dm default-dm.edc Default-dm.ini \( -iname "*.edc" -o -iname "*.ini" \)`; do
        # Highlight color
        if [[ "$HIGH_RGB" != "51 153 255" ]]; then
            sed -i "s/51 153 255/$HIGH_RGB/g" $F
            sed -i "s/#3399ff/$HIGH_HTML/g" $F
            sed -i "s/r = 51, g = 153, b = 255/r = $HIGH_RED, g = $HIGH_GREEN, b = $HIGH_BLUE/g" $F
        fi

        # File manager background
        if [[ "$FILEMGR_BKND_RGB" != "64 64 64" ]]; then
            sed -i "s/64 64 64/$FILEMGR_BKND_RGB/g" $F
            sed -i "s/#404040/$FILEMGR_BKND_HTML/g" $F
        fi

        # file manager alt
        if [[ "$FILEMGR_ALT_BKND_RGB" != "56 56 56" ]]; then
            sed -i "s/56 56 56/$FILEMGR_ALT_BKND_RGB/g" $F
            sed -i "s/#383838/$FILEMGR_ALT_BKND_HTML/g" $F
        fi

        # File manager image background
        if [[ "$FILEMGR_IMG_BKND_RGB" != "48 48 48" ]]; then
            sed -i "s/48 48 48/$FILEMGR_IMG_BKND_RGB/g" $F
            sed -i "s/#303030/$FILEMGR_IMG_BKND_HTML/g" $F
        fi

        # Grey boxes in pager
        if [[ "$FILEMGR_MID_GREY_RGB" != "50 50 50" ]]; then
            sed -i "s/50 50 50/$FILEMGR_MID_GREY_RGB/g" $F
            sed -i "s/#323232/$FILEMGR_MID_GREY_HTML/g" $F
        fi

        # modify html versions of text for textblock
        if [[ "$FNT_DEFAULT_HTML" != "#ffffff" ]]; then
            sed -i "s/#ffffff/$FNT_DEFAULT_HTML/gI" $F
            sed -i "s/#ffff/$FNT_DEFAULT_HTML/gI" $F
        fi

        if [[ "$FNT_DEFAULT_SHADOW_HTML" != "#00000080" ]]; then
            sed -i "s/#00000080/$FNT_DEFAULT_SHADOW_HTML/gI" $F
        fi

        # Disabled text
        if [[ "$FNT_DISABLED_HTML" != "#151515" ]]; then
            sed -i "s/#151515/$FNT_DISABLED_HTML/g" $F
        fi

        if [[ "$FNT_DISABLED_SHADOW_HTML" != "#FFFFFF19" ]]; then
            sed -i "s/#FFFFFF19/$FNT_DISABLED_SHADOW_HTML/gI" $F
        fi

        #terminology background
        if [[ "$TERMINOLOGY_BACKGROUND" != "#202020" ]]; then
            sed -i "s/#202020/$TERMINOLOGY_BACKGROUND/g" $F
        fi
    done

    # Some extra colorscheme
    sed -i "s/Default/$THEME_NAME/g" Default-dm.ini
    sed -i "s/Terminology's developers,/$THEME_AUTHOR/g" Default-dm.ini
    sed -i "s/https:////www.enlightenment.org//about-terminology/$THEME_WEB/g" Default-dm.ini

    mkdir -p ../build/term
    edje_cc -v -id $MANUAL_IMAGE_DIR -id img-color-convd -id img-no-change -sd sounds default-dm.edc $TERMINOLOGY_LICENSE $TERMINOLOGY_AUTHORS ../build/term/$THEME_NAME.edj

    report_on_error mv -v img-bak images

    if [[ $DKMD_TERMPKG != 1 ]]; then
      if [[ ! -d ~/.config/terminology/colorschemes ]]; then
        mkdir ~/.config/terminology/colorschemes
      fi
    fi

    inform "Creating Color Scheme"theme
    mkdir -p "../artifacts/bin-term"
    # Use any name thats not the default if it exists otherwise fall back to the recolored default
    INI_COUNT=$(ls -l *ini | grep -v "Default" | wc -l)
    if [[ $INI_COUNT > 0 ]]; then
    	for f in $(ls *.ini); do
    	  if [[ $f != "Default-dm.ini" && $f != "Default.ini" ]]; then
          ./add_color_scheme.sh "eet" "../build/term/${f%.*}.eet" "$f"
          cp "../build/term/${f%.*}.eet" "../artifacts/bin-term/"
          if [[ $f != "$THEME_NAME.eet" ]]; then
            termColorschemes+=("${f%.*}.eet")
          fi
    	  fi
    	done
    else
      ./add_color_scheme.sh "eet" "../build/term/$THEME_NAME.eet" "Default-dm.ini"
    fi

    if [[ ! -f ../build/term/$THEME_NAME.edj || ! -f ../build/term/$THEME_NAME.eet ]]; then
      error "Terminology theme or colorscheme not found build probably failed exiting"
      exit 1
    fi

    cp "../build/term/$THEME_NAME.edj" "../artifacts/bin-term/"

    rm *-EET-*

    if [[ $DKMD_TERMPKG != 1 ]]; then
	    report_on_error cp ../build/term/$THEME_NAME.edj ~/.config/terminology/themes
      for c in "${termColorschemes[@]}"; do
        report_on_error cp "../build/term/$c" ~/.config/terminology/colorschemes/
      done
    fi
    popd &> /dev/null # Terminology theme dir
fi
fi

if [[ $DKMD_EPKG = 0 && $DKMD_TERMPKG = 0 ]]; then
  inform "Creating Bundle"
   # Create Bundle
   pushd build &> /dev/null
   # Be Nice Copy Everything to a dir first.
   mkdir -p "$THEME_NAME-$THEME_VERSION-Bundle/e"
   mkdir -p "$THEME_NAME-$THEME_VERSION-Bundle/term"
   cp "../local-install.sh" "$THEME_NAME-$THEME_VERSION-Bundle/install.sh"
   sed -i "s/PLACEHOLDER/$THEME_NAME/g" "$THEME_NAME-$THEME_VERSION-Bundle/install.sh"
   cp "e/$THEME_NAME.edj" "$THEME_NAME-$THEME_VERSION-Bundle/e/"
   cp "term/$THEME_NAME.edj" "$THEME_NAME-$THEME_VERSION-Bundle/term/"
   for c in "${termColorschemes[@]}"; do
     cp "term/$c" "$THEME_NAME-$THEME_VERSION-Bundle/term/"
   done
   cp -r "icons/$THEME_NAME-icons/" "$THEME_NAME-$THEME_VERSION-Bundle"
   mkdir -p "../artifacts/bundle/"
   report_on_error tar -cf "../artifacts/bundle/$THEME_NAME-$THEME_VERSION-Bundle.tar.xz" "$THEME_NAME-$THEME_VERSION-Bundle"
   rm -r "$THEME_NAME-$THEME_VERSION-Bundle"
   popd &> /dev/null

  # TBD: copy back to current dir, and to .e file
fi
inform "Completed at: " $(date)
