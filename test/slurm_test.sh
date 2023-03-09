#!/bin/bash

################################################################################
## Batch script to run ROMS-JEDI Unit Test Cases with SLURM (like Rutger's     #
## AMAREL supercomputer.                                                       #
##                                                                             #
## THIS SCRIPT NEEDS TO BE RUN FROM:                                           #
##                                                                             #
##      <root-dir>/roms-jedi/build/roms-jedi                                   #
##                                                                             #
## To configure ROMS-JEDI in computer running SLURM, we nee to use:            #
##                                                                             #
##   ecbuild -DMPIEXEC_EXECUTABLE=$MPIRUN                                      #
##           -DMPI_ARGS="--mpi=pmi2"                                           #
##           -DMPIEXEC_NUMPROC_FLAG="-n"                                       #
##           -DROMS_BUILD_DIR=$ROMS_BUILD_DIR                                  #
##           -DCMAKE_BUILD_TYPE=Release ../bundle                              #
##                                                                             #
## where MPIRUN is set to /usr/bin/srun                                        #
##                                                                             #
################################################################################

##  SLURM configuration for AMAREL:
##
##  Use 'sbatch slurm_tests.sh'       to queue the job on HPC running SLURM
##  Use 'squeue -u harango'           to check our group jobs (including JOBID)
##  Use 'sacct -j JOBID -l'           to check job accounting data
##  Use 'scontrol show job JOBID'     to check job configuration
##  Use 'sinfo JOBID'                 to check job information
##  Use 'scancel JOBID'               to cancel a job

#SBATCH --exclusive                   # don't run on nodes running other jobs
#SBATCH --partition=p_omg_1           # Partition account
#SBATCH --requeue                     # Return job to the queue if preempted
#SBATCH --job-name=ROMSjedi           # Assign an short name to your job
#SBATCH --nodes=1                     # Number of nodes you require
#SBATCH --ntasks=2                    # Total number of tasks to launch
#SBATCH --ntasks-per-node=2           # Number of tasks to launch on each node
#SBATCH --cpus-per-task=1             # Cores per task (>1 if multithread tasks)
#SBATCH --mem=177000                  # Real memory (RAM) required (MB)
#SBATCH --time=00-00:10:00            # Total run time limit (DD-HH:MM:SS)
#SBATCH --output=log.tests            # STDOUT output file
#SBATCH --error=err.tests             # STDERR output file (optional)
#SBATCH --export=ALL                  # Export you current env to the job env

################################################################################

ALL_TEST=1       # Run all tests. Check ./Testing/Temporary/LastTest.log or
                 # (default)            ./Testing/Temporary/LastTestsFailed.log

NCPUS=2          # ROMS-JEDI Unit Tests is configured to run on 2 CPUs

ic=0             # Unit Tests counter


while [ $# -gt 0 ]
do
  case "$1" in
    -n )
      shift
      test=`echo $1 | grep '^[0-9]\+$'`
      if [ "$test" != "" ]; then
        NCPUS="$1"
        shift
      else
        NCPUS="2"
      fi
      ALL_TEST=0          # Run specific tests on scpecified number of CPUs
      ;;

    * )
      echo ""
      echo "$0 : Unknown option [ $1 ]"
      echo ""
      echo "Available Options:"
      echo ""
      echo "-n [M]      Run Unit Test Cases on M processes"
      echo ""
      exit 1
      ;;
  esac
done

MPIrun="/usr/bin/srun --mpi=pmi2 --ntasks=2 --cpu_bind=core --distribution=block:block"

export OOPS_TRACE=0                 # Set to 1 for tracing
export MAIN_DEBUG=1
export OOPS_DEBUG=1

export OMP_NUM_THREADS=8            # Used in BUMP

export HDF5_USE_FILE_LOCKING=FALSE

#-------------------------------------------------------------------------------
# Run all available or specific tests
#-------------------------------------------------------------------------------

if [ ${ALL_TEST} -eq 1 ]; then

  cd ../                       # go back to <root_dir>/roms-jedi/build/roms-jedi
  ctest -E -V get_
# ctest -V -R romsjedi_coding_norms

#-------------------------------------------------------------------------------
# Run specific Units Test on scpecified number of CPUs
#-------------------------------------------------------------------------------

else

  echo ""
  echo " MPI Command: ${MPIrun}"
  echo ""

  /bin/rm -f test_*.log test.err

  ic=$(( $ic + 1 ))
  ${MPIrun} test_romsjedi_geometry testinput/geometry.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_geometry ................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_geometry ................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} test_romsjedi_geometryiterator testinput/geometryiterator.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_geometryiterator ........  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_geometryiterator ........  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} test_romsjedi_state testinput/state.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_state ...................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_state ...................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} test_romsjedi_increment testinput/increment.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_increment ...............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_increment ...............  Passed"
  fi

  ${MPIrun} test_romsjedi_errorcovariance testinput/errorcovariance.yaml 1>> test_${ic}.log 2>> test.err
  ic=$(( $ic + 1 ))
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_errorcovariance .........  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_errorcovariance .........  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_hofx_nomodel.x testinput/hofx_nomodel.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_hofx_nomodel ............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_hofx_nomodel ............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_hofx.x testinput/hofx_4d.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_hofx_4d .................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_hofx_4d .................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_hofx.x testinput/makeobs_4d.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_makeobs_4d ..............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_makeobs_4d ..............  Passed"
  fi

  ${MPIrun} ../../bin/romsjedi_hofx.x testinput/makeobs_4d_perturbed.yaml 1>> test.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_makeobs_4d_petrubed .....  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_makeobs_4d_peturbed .....  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_diffstates.x testinput/diffstates.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_diffstates ..............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_diffstates ..............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_forecast.x testinput/forecast_roms.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_forecast_roms ...........  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_forecast_roms ...........  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} test_romsjedi_model testinput/model.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_model ...................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_model ...................  Passed"
  fi

  ${MPIrun} test_romsjedi_linearmodel testinput/linearmodel.yaml 1 >> test_${ic}.log 2>> test.err
  ic=$(( $ic + 1 ))
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_linearmodel .............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_linearmodel .............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_error_covariance_training.x testinput/parameters_bump_cor_nicas.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_bump_parameters_cor_nicas ........  *Failed"
  else
    echo " Test #${ic}: test_bump_parameters_cor_nicas ........  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_dirac.x testinput/dirac_roms_cor_nicas.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_dirac_roms_cor_nicas .............  *Failed"
  else
    echo " Test #${ic}: test_dirac_roms_cor_nicas .............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_enspert.x testinput/enspert.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_enspert .................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_enspert .................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dvar_zero_obs.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dvar_zero_obs ..........  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dvar_zero_obs ..........  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dvar_single_obs.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dvar_single_obs ........  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dvar_single_obs ........  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dvar_noLM.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dvar_noLM ..............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dvar_noLM ..............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dvar_fgat_DRPLanczos.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dvar_fgat_DRPLanczos ... *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dvar_fgat_DRPLanczos ...  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dvar_fgat_RPCG.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dvar_fgat_RPCG .........  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dvar_fgat_RPCG .........  Passed"
  fi

fi

exit 0
