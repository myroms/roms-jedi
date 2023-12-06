!/bin/bash

################################################################################
## Batch script to run ROMS-JEDI Unit Test Cases with SLURM in ORION           #
##                                                                             #
## THIS SCRIPT NEEDS TO BE RUN FROM:                                           #
##                                                                             #
##      <root-dir>/roms-jedi/build/roms-jedi                                   #
##                                                                             #
## Usage:                                                                      #
##                                                                             #
##   ./orion_test.sh [options]                                                 #
##                                                                             #
## Options:                                                                    #
##                                                                             #
##   -n [M]          Run Unit Test Cases on M processes (default M=2)          #
##                                                                             #
################################################################################

##  SLURM configuration for orion:
##
##  Use 'sbatch orion_tests.sh'        to queue the job NOAA's ORION HPC
##  Use 'squeue -u harango'            to check our group jobs (including JOBID)
##  Use 'sacct -j JOBID -l'            to check job accounting data
##  Use 'scontrol show job JOBID'      to check job configuration
##  Use 'sinfo JOBID'                  to check job information
##  Use 'scancel JOBID'                to cancel a job

##SBATCH --exclusive                   # don't run on nodes running other jobs
#SBATCH  --partition=debug             # Job queue, short runs (30 min max)
##SBATCH --partition=orion             # Partition (job queue), long runs
#SBATCH  --qos=debug                   # mid priority (30 min max)
##SBATCH --qos=windfall                # Low priority NOAA jobs (no time limit)
#SBATCH  --account=marine-cpu          # NOAA's ORION Allocation
#SBATCH  --job-name=ROMSjedi           # Assign an short name to your job
#SBATCH  --nodes=1                     # Number of nodes you require
#SBATCH  --ntasks=2                    # Total number of tasks to launch
#SBATCH  --ntasks-per-node=2           # Number of tasks to launch on each node
#SBATCH  --cpus-per-task=1             # Cores per task (>1 if multithread)
#SBATCH  --mem=1000                    # Real memory (RAM) required (MB)
#SBATCH  --time=00-00:05:00            # Total run time limit (DD-HH:MM:SS)
#SBATCH  --output=log.tests            # STDOUT output file
#SBATCH  --error=err.tests             # STDERR output file (optional)
#SBATCH  --export=ALL                  # Export you current env to the job env

################################################################################

# Unit Test setup.

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

# Specific ORION computer environmental variables.

source /etc/bashrc
module purge
export JEDI_OPT=/work/noaa/da/grubin/opt/modules
module use $JEDI_OPT/modulefiles/core
module load jedi/intel-impi
module list
ulimit -s unlimited

export SLURM_EXPORT_ENV=ALL
export HDF5_USE_FILE_LOCKING=FALSE

MPIrun="srun --ntasks=2 --cpu_bind=core --distribution=block:block"

# Run all avialable or specific tests

export MAIN_DEBUG=1
export OOPS_DEBUG=1
export OOPS_TRACE=0                 # Set to 1 for tracing

export LdebugAnalyticInit=0         # ROMS-JEDI Classes debugging switches
export LdebugField=0
export LdebugFields=0
export LdebugFieldsUtils=0
export LdebugGeometry=0
export LdebugLinearModel=0
export LdebugLinearModel2Geovals=0
export LdebugModel=0
export LdebugModel2Geovals=0
export LdebugTrajectory=0

export OMP_NUM_THREADS=8            # Used in BUMP

export HDF5_USE_FILE_LOCKING=FALSE

#-------------------------------------------------------------------------------
# Run all available Unit Tests: Use 'ctest -N' to list available tests.
#-------------------------------------------------------------------------------

if [ ${ALL_TEST} -eq 1 ]; then
  cd ../                       # go back to <root_dir>/roms-jedi/build/roms-jedi
  ctest -E -V get_

#-------------------------------------------------------------------------------
# Run individual Unit Tests.
#-------------------------------------------------------------------------------

elif [ ${ALL_TEST} -eq 2 ]; then

  cd ../                       # go back to <root_dir>/roms-jedi/build/roms-jedi

  ctest -VV -R romsjedi_coding_norms
  ctest -VV -R test_romsjedi_geometry
  ctest -VV -R test_romsjedi_geometryiterator
  ctest -VV -R test_romsjedi_state
  ctest -VV -R test_romsjedi_increment
  ctest -VV -R test_romsjedi_model
  ctest -VV -R test_romsjedi_linearmodel
  ctest -VV -R test_romsjedi_error_covariance
  ctest -VV -R test_romsjedi_hofx_nomodel
  ctest -VV -R test_romsjedi_hofx_4d
  ctest -VV -R test_romsjedi_makeobs_4d
  ctest -VV -R test_romsjedi_makeobs_4d_perturbed
  ctest -VV -R test_romsjedi_diffstates
  ctest -VV -R test_romsjedi_forecast_roms
  ctest -VV -R test_romsjedi_bump_parameters_cor_nicas
  ctest -VV -R test_romsjedi_bump_loc_parameters_cor_nicas
  ctest -VV -R test_romsjedi_dirac_cov_nicas
  ctest -VV -R test_romsjedi_ens_pert
  ctest -VV -R test_romsjedi_ens_meanandvariance
  ctest -VV -R test_romsjedi_ens_recenter
  ctest -VV -R test_romsjedi_ens_hofx
  ctest -VV -R test_romsjedi_dirac_ens_cov_nicas
  ctest -VV -R test_romsjedi_3dvar_zero_obs
  ctest -VV -R test_romsjedi_3dvar_regular_single_obs
  ctest -VV -R test_romsjedi_3dfgat_single_obs
  ctest -VV -R test_romsjedi_4dfgat_single_obs
  ctest -VV -R test_romsjedi_3dvar_regular_primal
  ctest -VV -R test_romsjedi_3dvar_regular_dual
  ctest -VV -R test_romsjedi_3dfgat_primal
  ctest -VV -R test_romsjedi_3fgat_dual
  ctest -VV -R test_romsjedi_4dfgat_primal
  ctest -VV -R test_romsjedi_4dfgat_dual
  ctest -VV -R test_romsjedi_3denvar_regular_primal
  ctest -VV -R test_romsjedi_3denvar_regular_dual
  ctest -VV -R test_romsjedi_3denvar_4dfgat_primal
  ctest -VV -R test_romsjedi_3denvar_4dfgat_dual
  ctest -VV -R test_romsjedi_3dhyb_regular_primal
  ctest -VV -R test_romsjedi_3dhyb_regular_dual
  ctest -VV -R test_romsjedi_3dhyb_4dfgat_primal
  ctest -VV -R test_romsjedi_3dhyb_4dfgat_dual
  ctest -VV -R test_romsjedi_letkf
  ctest -VV -R test_romsjedi_letkf_split_observer
  ctest -VV -R test_romsjedi_letkf_split_solver
  ctest -VV -R test_romsjedi_letkf_3dhyb

#-------------------------------------------------------------------------------
# Run specific Units Test on scpecified number of CPUs (use during debugging).
#-------------------------------------------------------------------------------

else

  echo ""
  echo " MPI Command: ${MPIrun}"
  echo ""

  /bin/rm -f test_*.log test.err

  ic=$(( $ic + 1 ))
  ${MPIrun} test_romsjedi_geometry testinput/geometry.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_geometry ........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_geometry ........................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} test_romsjedi_geometryiterator testinput/geometryiterator.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_geometryiterator ................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_geometryiterator ................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} test_romsjedi_state testinput/state.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_state ...........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_state ...........................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} test_romsjedi_increment testinput/increment.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_increment .......................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_increment .......................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} test_romsjedi_model testinput/model.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_model ...........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_model ...........................  Passed"
  fi

  ${MPIrun} test_romsjedi_linearmodel testinput/linearmodel.yaml 1 >> test_${ic}.log 2>> test.err
  ic=$(( $ic + 1 ))
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_linearmodel .....................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_linearmodel .....................  Passed"
  fi

  ${MPIrun} test_romsjedi_error_covariance testinput/error_covariance.yaml 1>> test_${ic}.log 2>> test.err
  ic=$(( $ic + 1 ))
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_error_covariance ................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_error_covariance ................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_hofx_nomodel.x testinput/hofx_nomodel.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_hofx_nomodel ....................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_hofx_nomodel ....................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_hofx.x testinput/hofx_4d.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_hofx_4d .........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_hofx_4d .........................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_hofx.x testinput/makeobs_4d.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_makeobs_4d ......................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_makeobs_4d ......................  Passed"
  fi

  ${MPIrun} ../../bin/romsjedi_hofx.x testinput/makeobs_4d_perturbed.yaml 1>> test.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_makeobs_4d_petrubed .............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_makeobs_4d_peturbed .............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_diffstates.x testinput/diffstates.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_diffstates ......................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_diffstates ......................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_forecast.x testinput/forecast_roms.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_forecast_roms ...................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_forecast_roms ...................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_error_covariance_toolbox.x testinput/parameters_bump_cor_nicas.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_bump_parameters_cor_nicas .......  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_bump_parameters_cor_nicas .......  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_error_covariance_toolbox.x testinput/parameters_bump_loc_cor_nicas.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_bump_loc_parameters_cor_nicas ... *Failed"
  else
    echo " Test #${ic}: test_romsjedi_bump_loc_parameters_cor_nicas ...  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_error_covariance_toolbox.x testinput/dirac_cov_nicas.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_dirac_cov_nicas .................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_dirac_cov_nicas .................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_ens_pert.x testinput/ens_perturbation.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_ens_pert ........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_ens_pert ........................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_ens_meanandvariance.x testinput/ens_meanandvariance.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_ens_meanandvariance .............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_ens_meanandvariance .............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_ens_recenter.x testinput/ens_recenter.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_ens_recenter ....................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_ens_recenter ....................  Passed"
  fi

  ic=$(( $ic + 1 ))
  mpirun -n 6 ../../bin/romsjedi_ens_hofx.x testinput/ens_hofx.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_ens_hofx ........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_ens_hofx ........................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_error_covariance_toolbox.x testinput/dirac_ens_cov_nicas.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_dirac_ens_cov_nicas .............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_dirac_ens_cov_nicas .............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dvar_zero_obs.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dvar_zero_obs ..................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dvar_zero_obs ..................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dvar_regular_single_obs.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dvar_regular_single_obs ........ *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dvar_regular_single_obs ........  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dfgat_single_obs.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dfgat_single_obs .............. *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dfgat_single_obs ..............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/4dfgat_single_obs.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_4dfgat_single_obs .............. *Failed"
  else
    echo " Test #${ic}: test_romsjedi_4dfgat_single_obs ..............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dvar_regular_primal.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dvar_regular_primal ............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dvar_regular_primal ............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dvar_regular_dual.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dvar_regular_dual ..............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dvar_regular_dual ..............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dfgat_primal.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dfgat_primal ................... *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dfgat_primal ...................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dfgat_dual.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dfgat_dual .....................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dfgat_dual .....................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/4dfgat_primal.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_4dfgat_primal ................... *Failed"
  else
    echo " Test #${ic}: test_romsjedi_4dfgat_primal ...................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/4dfgat_dual.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_4dfgat_dual .....................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_4dfgat_dual .....................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3denvar_regular_primal.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3denvar_regular_primal ..........  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3denvar_regular_primal ..........  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3denvar_regular_dual.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3denvar_regular_dual ............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3denvar_regular_dual ............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3denvar_4dfgat_primal.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3denvar_4dfgat_primal ...........  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3denvar_4dfgat_primal ...........  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3denvar_4dfgat_dual.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3denvar_4dfgat_dual .............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3denvar_4dfgat_dual ...........  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3denvar_regular_dual.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3denvar_regular_dual ............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3denvar_regular_dual ............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dhyb_regular_primal.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dhyb_regular_primal ............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dhyb_regular_primal ............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dhyb_regular_dual.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dhyb_regular_dual ..............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dhyb_regular_dual ..............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dhyb_4dfgat_primal.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dhyb_4dfgat_primal .............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dhyb_4dfgat_primal .............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dhyb_4dfgat_dual.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dhyb_4dfgat_dual ...............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dhyb_4dfgat_dual ...............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_letkf.x testinput/letkf.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_letkf ...........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_letkf ...........................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_letkf.x testinput/letkf_split_observer.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_letkf_split_observer ............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_letkf_split_observer ............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_letkf.x testinput/letkf_split_solver.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_letkf_split_solver ..............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_letkf_split_solver ..............  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/letkf_3dhyb.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_letkf_3dhyb .....................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_letkf_3dhyb .....................  Passed"
  fi

fi

exit 0
