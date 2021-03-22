#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib"
#FIXME: no compiled matlab support
g_matlab_default_mode=1

#this function gets called by opts_ParseArguments when --help is specified
function usage()
{
    #header text
    echo "
$log_ToolName: does stuff

Usage: $log_ToolName PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value
"
    #automatic argument descriptions
    opts_ShowArguments
    
    #do not use exit, the parsing code takes care of it
}

#arguments to opts_Add*: switch, variable to set, name for inside of <> in help text, description, [default value if AddOptional], [compatibility flag, ...]
#help info for option gets printed like "--foo=<$3> - $4"
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject-list' 'Subjlist' '100206@100307...' 'list of subject IDs separated by @s'
opts_AddMandatory '--fmri-names' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' 'list of fmri run names separated by @s'
opts_AddMandatory '--out-fmri-name' 'OutputfMRIName' 'name' 'name component to use for outputs'
opts_AddMandatory '--proc-string' 'fMRIProcSTRING' 'string' 'name component used while preprocessing inputs'
#maybe make this the absolute group folder path?
opts_AddMandatory '--out-group-name' 'GroupAverageName' 'string' 'name to use for the output folder'
opts_AddMandatory '--pca-internal-dim' 'PCAInternalDim' 'integer' 'internal MIGP dimensionality'
opts_AddMandatory '--pca-out-dim' 'PCAOutputDim' 'integer' 'number of components to output'
opts_AddOptional '--matlab-run-mode' 'MatlabMode' '0, 1, or 2' "defaults to $g_matlab_default_mode
0 = compiled MATLAB (not implemented)
1 = interpreted MATLAB
2 = Octave" "$g_matlab_default_mode"
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

case "$MatlabMode" in
    (0)
        log_Err_Abort "FIXME: compiled matlab support not yet implemented"
        ;;
    (1)
        #NOTE: figure() is required by the spectra option, and -nojvm prevents using figure()
        matlab_interpreter=(matlab -nodisplay -nosplash)
        ;;
    (2)
        matlab_interpreter=(octave-cli -q --no-window-system)
        ;;
    (*)
        log_Err_Abort "unrecognized matlab mode '$MatlabMode', use 0, 1, or 2"
        ;;
esac

#Naming Conventions
CommonAtlasFolder="$StudyFolder/$GroupAverageName/MNINonLinear"
OutputFolder="$CommonAtlasFolder/Results/$OutputfMRIName"

OutputPCA="$OutputFolder/${OutputfMRIName}${fMRIProcSTRING}"

mkdir -p "$OutputFolder"

tempfiles_add "$OutputFolder/${OutputfMRIName}${fMRIProcSTRING}.txt"
echo "$Subjlist" | tr @ '\n' > "$OutputFolder/${OutputfMRIName}${fMRIProcSTRING}.txt"
fMRINamesML="{'"$(echo "$fMRINames" | sed "s/@/';'/g")"'}"

mlcode="addpath('$HCPPIPEDIR/global/matlab'); addpath('$HCPPIPEDIR/tICA/scripts'); addpath('$HCPCIFTIRWDIR'); MIGP('$StudyFolder', '$OutputFolder/${OutputfMRIName}${fMRIProcSTRING}.txt', $fMRINamesML, '$fMRIProcSTRING', $PCAInternalDim, $PCAOutputDim, '$OutputPCA');"

log_Msg "running matlab code: $mlcode"
"${matlab_interpreter[@]}" <<<"$mlcode"
