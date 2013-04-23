#!/bin/bash
set -e
echo -e "\n START: eddy_postproc"

#Hard-Coded filename. Flag from eddy to indicate that the jac method has been used for resampling
EddyJacFlag="JacobianResampling" 

workingdir=$1
binarydir=$2
configdir=$3

eddydir=${workingdir}/eddy
datadir=${workingdir}/data

#Prepare for next eddy Release
#if [ ! -e ${eddydir}/${EddyJacFlag} ]; then 
#    echo "LSR resampling has been used. Eddy Output has already been combined."
#    cp ${eddydir}/Pos.bval ${datadir}/bvals
#    cp ${eddydir}/Pos.bvec ${datadir}/bvecs
#    $FSLDIR/bin/imcp ${eddydir}/eddy_unwarped_images ${datadir}/data
#else
     echo "JAC resampling has been used. Eddy Output is now combined."
     PosVols=`wc ${eddydir}/Pos.bval | awk {'print $2'}`
     NegVols=`wc ${eddydir}/Neg.bval | awk {'print $2'}`    #Split Pos and Neg Volumes
     ${FSLDIR}/bin/fslroi ${eddydir}/eddy_unwarped_images ${eddydir}/eddy_unwarped_Pos 0 ${PosVols}
     ${FSLDIR}/bin/fslroi ${eddydir}/eddy_unwarped_images ${eddydir}/eddy_unwarped_Neg ${PosVols} ${NegVols}
     ${binarydir}/eddy_combine ${eddydir}/eddy_unwarped_Pos ${eddydir}/Pos.bval ${eddydir}/Pos.bvec ${eddydir}/Pos_SeriesVolNum.txt \
                                        ${eddydir}/eddy_unwarped_Neg ${eddydir}/Neg.bval ${eddydir}/Neg.bvec ${eddydir}/Neg_SeriesVolNum.txt ${datadir} 1

     ${FSLDIR}/bin/imrm ${eddydir}/eddy_unwarped_Pos
     ${FSLDIR}/bin/imrm ${eddydir}/eddy_unwarped_Neg
     #rm ${eddydir}/Pos.bv*
     #rm ${eddydir}/Neg.bv*
#fi

${FSLDIR}/bin/immv ${datadir}/data ${datadir}/data_warped
$FSLDIR/bin/fslroi ${datadir}/data_warped ${datadir}/nodif_warped 0 1


echo "Computing gradient coil tensor to correct for gradient nonlinearities"
cd ${datadir} #Warp field output of gradient_unwarp.py is always produced in the current directory
gradient_unwarp.py ${datadir}/nodif_warped.nii.gz ${datadir}/nodif.nii.gz siemens -g ${configdir}/coeff_SC72C_Skyra.grad -n
${FSLDIR}/bin/convertwarp --abs --ref=${datadir}/fullWarp_abs --warp1=${datadir}/fullWarp_abs --relout --out=${datadir}/fullWarp
${binarydir}/calc_grad_perc_dev --fullwarp=${datadir}/fullWarp -o ${datadir}/grad_dev
${FSLDIR}/bin/fslmerge -t ${datadir}/grad_dev ${datadir}/grad_dev_x ${datadir}/grad_dev_y ${datadir}/grad_dev_z
${FSLDIR}/bin/fslmaths ${datadir}/grad_dev -div 100 ${datadir}/grad_dev #Convert from % deviation to absolute
${FSLDIR}/bin/imrm ${datadir}/grad_dev_?
${FSLDIR}/bin/imrm ${datadir}/nodif_warped

#This produces unwarped images in diffusion space. Remove or keep it for debugging?
echo "Correcting for gradient nonlinearities"

${FSLDIR}/bin/applywarp --rel -i ${datadir}/data_warped -r ${datadir}/nodif -w ${datadir}/fullWarp --interp=spline -o ${datadir}/data

#Remove negative intensity values (caused by spline interpolation) from final data
${FSLDIR}/bin/fslmaths ${datadir}/data -thr 0 ${datadir}/data
${FSLDIR}/bin/bet ${datadir}/data ${datadir}/nodif_brain -m -f 0.1

#Keep the original warped data and warp fields
mkdir -p ${datadir}/warped
${FSLDIR}/bin/immv ${datadir}/data_warped ${datadir}/warped
${FSLDIR}/bin/immv ${datadir}/fullWarp ${datadir}/warped

echo -e "\n END: eddy_postproc"
