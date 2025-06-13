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
export LdebugLinearModel2Analysis=0
export LdebugLinearModel2Geovals=0
export LdebugModel=0
export LdebugModel2Analysis=0
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
  ctest -VV -R test_romsjedi_variableChange
  ctest -VV -R test_romsjedi_linearVariableChange
  ctest -VV -R test_romsjedi_hofx_3d
  ctest -VV -R test_romsjedi_hofx_4d
  ctest -VV -R test_romsjedi_makeobs
  ctest -VV -R test_romsjedi_makeobs_perturbed
  ctest -VV -R test_romsjedi_diffstates
  ctest -VV -R test_romsjedi_forecast_roms
  ctest -VV -R test_romsjedi_bump_parameters_cor_nicas
  ctest -VV -R test_romsjedi_bump_parameters_cor_nicas_max
  ctest -VV -R test_romsjedi_parameters_diffusion
  ctest -VV -R test_romsjedi_bump_loc_parameters_cor_nicas
  ctest -VV -R test_romsjedi_bump_loc_parameters_cor_nicas_max
  ctest -VV -R test_romsjedi_dirac_cov_nicas
  ctest -VV -R test_romsjedi_dirac_diffusion
  ctest -VV -R test_romsjedi_ens_perturbation
  ctest -VV -R test_romsjedi_ens_meanandvariance
  ctest -VV -R test_romsjedi_ens_recenter
  ctest -VV -R test_romsjedi_ens_hofx
  ctest -VV -R test_romsjedi_dirac_ens_cov_nicas
  ctest -VV -R test_romsjedi_3dvar_zeroObs
  ctest -VV -R test_romsjedi_3dvar_singleObs
  ctest -VV -R test_romsjedi_3dfgat_singleObs
  ctest -VV -R test_romsjedi_4dfgat_singleObs
  ctest -VV -R test_romsjedi_3dvar_primal
  ctest -VV -R test_romsjedi_3dvar_dual
  ctest -VV -R test_romsjedi_3dfgat_primal
  ctest -VV -R test_romsjedi_3dfgat_dual
  ctest -VV -R test_romsjedi_4dfgat_primal
  ctest -VV -R test_romsjedi_4dfgat_dual
  ctest -VV -R test_romsjedi_4dvar_singleObs_bump
  ctest -VV -R test_romsjedi_4dvar_singleObs_diffusion
  ctest -VV -R test_romsjedi_4dvar_bump
  ctest -VV -R test_romsjedi_4dvar_diffusion
  ctest -VV -R test_romsjedi_3denvar_nofgat_primal
  ctest -VV -R test_romsjedi_3denvar_nofgat_dual
  ctest -VV -R test_romsjedi_3denvar_4dfgat_primal
  ctest -VV -R test_romsjedi_3denvar_4dfgat_dual
  ctest -VV -R test_romsjedi_3dhyb_nofgat_primal
  ctest -VV -R test_romsjedi_3dhyb_nofgat_dual
  ctest -VV -R test_romsjedi_3dhyb_4dfgat_primal
  ctest -VV -R test_romsjedi_3dhyb_4dfgat_dual
  ctest -VV -R test_romsjedi_letkf_solver
  ctest -VV -R test_romsjedi_letkf_splitObserver
  ctest -VV -R test_romsjedi_letkf_splitSolver
  ctest -VV -R test_romsjedi_letkf_3dhyb

#-------------------------------------------------------------------------------
# Run specific Units Test on scpecified number of CPUs (use during debugging).
#
# mpirun -n 2  test_romsjedi_geometry testinput/geometry.yaml
# mpirun -n 2  test_romsjedi_geometryiterator testinput/geometryiterator.yaml
# mpirun -n 2  test_romsjedi_state testinput/state.yaml
# mpirun -n 2  test_romsjedi_increment testinput/increment.yaml
# mpirun -n 2  test_romsjedi_model testinput/model.yaml
# mpirun -n 2  test_romsjedi_linearmodel testinput/linearmodel.yaml
# mpirun -n 2  test_romsjedi_variableChange testinput/variableChange.yaml
# mpirun -n 2  test_romsjedi_linearVariableChange testinput/linearVariableChange.yaml
# mpirun -n 2  ../../bin/romsjedi_hofx3d.x testinput/hofx_3d.yaml
# mpirun -n 2  ../../bin/romsjedi_hofx4d.x testinput/hofx_4d.yaml
# mpirun -n 2  ../../bin/romsjedi_hofx4d.x testinput/makeobs.yaml
# mpirun -n 2  ../../bin/romsjedi_hofx4d.x testinput/makeobs_perturbed.yaml
# mpirun -n 2  ../../bin/romsjedi_diffstates.x testinput/diffstates.yaml
# mpirun -n 12 ../../bin/romsjedi_forecast.x testinput/forecast_roms.yaml
# mpirun -n 2  ../../bin/romsjedi_error_covariance_toolbox.x testinput/parameters_bump_cor_nicas.yaml
# mpirun -n 12 ../../bin/romsjedi_error_covariance_toolbox.x testinput/parameters_bump_cor_nicas_max.yaml
# mpirun -n 2  ../../bin/romsjedi_error_covariance_toolbox.x testinput/parameters_diffusion.yaml
# mpirun -n 2  ../../bin/romsjedi_error_covariance_toolbox.x testinput/parameters_bump_loc_cor_nicas.yaml
# mpirun -n 12 ../../bin/romsjedi_error_covariance_toolbox.x testinput/parameters_bump_loc_cor_nicas_max.yaml
# mpirun -n 2  ../../bin/romsjedi_error_covariance_toolbox.x testinput/dirac_cov_nicas.yaml
# mpirun -n 2  ../../bin/romsjedi_error_covariance_toolbox.x testinput/dirac_diffusion.yaml
# mpirun -n 12 ../../bin/romsjedi_ens_pert.x testinput/ens_perturbation.yaml
# mpirun -n 2  ../../bin/romsjedi_ens_meanandvariance.x testinput/ens_meanandvariance.yaml
# mpirun -n 2  ../../bin/romsjedi_ens_recenter.x testinput/ens_recenter.yaml
# mpirun -n 6  ../../bin/romsjedi_ens_hofx.x testinput/ens_hofx.yaml
# mpirun -n 2  ../../bin/romsjedi_error_covariance_toolbox.x testinput/dirac_ens_cov_nicas.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/3dvar_zeroObs.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/3dvar_singleObs.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/3dfgat_singleObs.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/4dfgat_singleObs.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/3dvar_primal.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/3dvar_dual.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/3dfgat_primal.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/3dfgat_dual.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/4dfgat_primal.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/4dfgat_dual.yaml
# mpirun -n 12 ../../bin/romsjedi_var.x testinput/4dvar_bump_singleObs.yaml
# mpirun -n 12 ../../bin/romsjedi_var.x testinput/4dvar_diffusion_singleObs.yaml
# mpirun -n 12 ../../bin/romsjedi_var.x testinput/4dvar_bump.yaml
# mpirun -n 12 ../../bin/romsjedi_var.x testinput/4dvar_diffusion.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/3denvar_nofgat_primal.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/3denvar_nofgat_dual.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/3denvar_4dfgat_primal.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/3denvar_4dfgat_dual.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/3dhyb_nofgat_primal.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/3dhyb_nodgat_dual.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/3dhyb_4dfgat_primal.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/3dhyb_4dfgat_dual.yaml
# mpirun -n 2  ../../bin/romsjedi_letkf.x testinput/letkf_solver.yaml
# mpirun -n 2  ../../bin/romsjedi_letkf.x testinput/letkf_splitObserver.yaml
# mpirun -n 2  ../../bin/romsjedi_letkf.x testinput/letkf_splitSolver.yaml
# mpirun -n 2  ../../bin/romsjedi_var.x testinput/letkf_3dhyb.yaml
#-------------------------------------------------------------------------------

else

  echo ""
  echo " MPI Command: ${MPIrun}"
  echo ""

  /bin/rm -f test_*.log test.err

  ic=$(( $ic + 1 ))
  ${MPIrun} test_romsjedi_geometry testinput/geometry.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_geometry .............................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_geometry .............................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} test_romsjedi_geometryiterator testinput/geometryiterator.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_geometryiterator .....................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_geometryiterator .....................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} test_romsjedi_state testinput/state.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_state ................................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_state ................................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} test_romsjedi_increment testinput/increment.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_increment ............................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_increment ............................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} test_romsjedi_model testinput/model.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_model ................................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_model ................................  Passed"
  fi

  ${MPIrun} test_romsjedi_linearmodel testinput/linearmodel.yaml 1 >> test_${ic}.log 2>> test.err
  ic=$(( $ic + 1 ))
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_linearmodel ..........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_linearmodel ..........................  Passed"
  fi

  ${MPIrun} test_romsjedi_VariableChange testinput/variableChange.yaml 1 >> test_${ic}.log 2>> test.err
  ic=$(( $ic + 1 ))
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_variableChange .......................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_variableChange .......................  Passed"
  fi

  ${MPIrun} test_romsjedi_linearVariableChange testinput/linearVariableChange.yaml 1 >> test_${ic}.log 2>> test.err
  ic=$(( $ic + 1 ))
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_linearVariableChange .................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_linearVariableChange .................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_hofx3d.x testinput/hofx_3d.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_hofx3d ...............................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_hofx3d ...............................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_hofx4d.x testinput/hofx_4d.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_hofx4d ...............................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_hofx4d ...............................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_hofx4d.x testinput/makeobs.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_makeobs ..............................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_makeobs ..............................  Passed"
  fi

  ${MPIrun} ../../bin/romsjedi_hofx4d.x testinput/makeobs_perturbed.yaml 1>> test.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_makeobs_petrubed .....................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_makeobs_peturbed .....................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_diffstates.x testinput/diffstates.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_diffstates ...........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_diffstates ...........................  Passed"
  fi

  ic=$(( $ic + 1 ))
  mpirun -n 12 ../../bin/romsjedi_forecast.x testinput/forecast_roms.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_forecast_roms ........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_forecast_roms ........................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_error_covariance_toolbox.x testinput/parameters_bump_cor_nicas.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_bump_parameters_cor_nicas ............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_bump_parameters_cor_nicas ............  Passed"
  fi

  ic=$(( $ic + 1 ))
  mpirun -n 12 ../../bin/romsjedi_error_covariance_toolbox.x testinput/parameters_bump_cor_nicas_max.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_bump_parameters_cor_nicas_max ........  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_bump_parameters_cor_nicas_max ........  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_error_covariance_toolbox.x testinput/parameters_diffusion.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_parameters_diffusion .................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_parameters_diffusion .................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_error_covariance_toolbox.x testinput/parameters_bump_loc_cor_nicas.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_bump_loc_parameters_cor_nicas ........  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_bump_loc_parameters_cor_nicas ........  Passed"
  fi

  ic=$(( $ic + 1 ))
  mpirun -n 12 ../../bin/romsjedi_error_covariance_toolbox.x testinput/parameters_bump_loc_cor_nicas_max.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_bump_loc_parameters_cor_nicas_max ....  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_bump_loc_parameters_cor_nicas_max ....  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_error_covariance_toolbox.x testinput/dirac_cov_nicas.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_dirac_cov_nicas ......................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_dirac_cov_nicas ......................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_error_covariance_toolbox.x testinput/dirac_diffusion.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_dirac_diffusion ......................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_dirac_diffusion ......................  Passed"
  fi

  ic=$(( $ic + 1 ))
  mpirun -n 12 ../../bin/romsjedi_ens_pert.x testinput/ens_perturbation.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_ens_perturbation .....................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_ens_perturbation .....................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_ens_meanandvariance.x testinput/ens_meanandvariance.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_ens_meanandvariance ..................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_ens_meanandvariance ..................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_ens_recenter.x testinput/ens_recenter.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_ens_recenter .........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_ens_recenter .........................  Passed"
  fi

  ic=$(( $ic + 1 ))
  mpirun -n 6 ../../bin/romsjedi_ens_hofx.x testinput/ens_hofx.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_ens_hofx .............................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_ens_hofx .............................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_error_covariance_toolbox.x testinput/dirac_ens_cov_nicas.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_dirac_ens_cov_nicas ..................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_dirac_ens_cov_nicas ..................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dvar_zeroObs.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dvar_zeroObs ........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dvar_zeroObs ........................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dvar_singleObs.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dvar_singleObs ......................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dvar_singleObs ......................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dfgat_singleObs.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dfgat_singleObs .....................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dfgat_singleObs .....................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/4dfgat_singleObs.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_4dfgat_singleObs .....................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_4dfgat_singleObs .....................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dvar_primal.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dvar_primal .........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dvar_primal .........................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dvar_dual.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dvar_dual ...........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dvar_dual ...........................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dfgat_primal.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dfgat_primal ........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dfgat_primal ........................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dfgat_dual.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dfgat_dual ..........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dfgat_dual ..........................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/4dfgat_primal.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_4dfgat_primal ........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_4dfgat_primal ........................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/4dfgat_dual.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_4dfgat_dual ..........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_4dfgat_dual ..........................  Passed"
  fi

  ic=$(( $ic + 1 ))
  mpirun -n 12 ../../bin/romsjedi_var.x testinput/4dvar_singleObs_bump.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_4dvar_singleObs_bump .................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_4dvar_singleObs_bump .................  Passed"
  fi

  ic=$(( $ic + 1 ))
  mpirun -n 12 ../../bin/romsjedi_var.x testinput/4dvar_singleObs_diffusion.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_4dvar_singleObs_diffusion ............  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_4dvar_singleObs_diffusion ............  Passed"
  fi

  ic=$(( $ic + 1 ))
  mpirun -n 12 ../../bin/romsjedi_var.x testinput/4dvar_bump.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_4dvar_bump ...........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_4dvar_bump ...........................  Passed"
  fi

  ic=$(( $ic + 1 ))
  mpirun -n 12 ../../bin/romsjedi_var.x testinput/4dvar_diffusion.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_4dvar_diffusion ......................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_4dvar_diffusion ......................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3denvar_nofgat_primal.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3denvar_nofgat_primal ................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3denvar_nofgat_primal ................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3denvar_nofgat_dual.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3denvar_nofgat_dual ..................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3denvar_nofgat_dual ..................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3denvar_4dfgat_primal.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3denvar_4dfgat_primal ................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3denvar_4dfgat_primal ................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3denvar_4dfgat_dual.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3denvar_4dfgat_dual ..................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3denvar_4dfgat_dual ..................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dhyb_nofgat_primal.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dhyb_nofgat_primal ..................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dhyb_nofgat_primal ..................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dhyb_nofgat_dual.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dhyb_nofgat_dual ....................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dhyb_nofgat_dual ....................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dhyb_4dfgat_primal.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dhyb_4dfgat_primal ..................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dhyb_4dfgat_primal ..................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/3dhyb_4dfgat_dual.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_3dhyb_4dfgat_dual ....................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_3dhyb_4dfgat_dual ....................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_letkf.x testinput/letkf_solver.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_letkf ................................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_letkf ................................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_letkf.x testinput/letkf_splitObserver.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_letkf_splitObserver ..................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_letkf_splitObserver ..................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_letkf.x testinput/letkf_splitSolver.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_letkf_splitSolver ....................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_letkf_splitSolver ....................  Passed"
  fi

  ic=$(( $ic + 1 ))
  ${MPIrun} ../../bin/romsjedi_var.x testinput/letkf_3dhyb.yaml 1>> test_${ic}.log 2>> test.err
  if [ $? -ne 0 ] ; then
    echo " Test #${ic}: test_romsjedi_letkf_3dhyb ..........................  *Failed"
  else
    echo " Test #${ic}: test_romsjedi_letkf_3dhyb ..........................  Passed"
  fi

fi

exit 0
