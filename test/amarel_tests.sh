#!/bin/bash

################################################################################
## Batch script to run ROMS-JEDI Unit Test Cases with SLURM in AMAREL          #
##                                                                             #
## THIS SCRIPT NEEDS TO BE RUN FROM:                                           #
##                                                                             #
##      <root-dir>/roms-jedi/build/roms-jedi                                   #
##                                                                             #
## To configure ROMS-JEDI in AMAREL, we nee to use:                            #
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

##  SLURM configuration for orion:
##
##  Use 'sbatch orion_tests.sh'       to queue the job NOAA's ORION HPC
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

export OOPS_TRACE=0                       # Set to 1 for tracing
export MAIN_DEBUG=1
export OOPS_DEBUG=1

export OMP_NUM_THREADS=8                  # Used in BUMP

export HDF5_USE_FILE_LOCKING=FALSE

MPIrun="/usr/bin/srun --mpi=pmi2 --ntasks=2 --cpu_bind=core --distribution=block:block"

# Run all avialable or specific tests

#ALL_TEST=0      # Run specific tests. caseheck ./log.tests
 ALL_TEST=1      # Run all tests. Check ./Testing/Temporary/LastTest.log
                 #                      ./Testing/Temporary/LastTestsFailed.log

if [ ${ALL_TEST} -eq 1 ]; then
  cd ../                       # go back to <root_dir>/roms-jedi/build/roms-jedi
  ctest -E -V get_
# ctest -V -R romsjedi_coding_norms
else
  ${MPIrun} test_romsjedi_geometry testinput/geometry.yaml
  ${MPIrun} test_romsjedi_geometryiterator testinput/geometryiterator.yaml
  ${MPIrun} test_romsjedi_state testinput/state.yaml
  ${MPIrun} test_romsjedi_getvalues testinput/getvalues.yaml
  ${MPIrun} ../../bin/romsjedi_hofx_nomodel.x testinput/hofx_nomodel.yaml
  ${MPIrun} ../../bin/romsjedi_hofx.x testinput/hofx_4d.yaml
  ${MPIrun} ../../bin/romsjedi_hofx.x testinput/makeobs_4d.yaml
  ${MPIrun} ../../bin/romsjedi_hofx.x testinput/makeobs_4d_perturbed.yaml
  ${MPIrun} test_romsjedi_increment testinput/increment.yaml
  ${MPIrun} ../../romsjedi_diffstates.x testinput/diffstates.yaml
  ${MPIrun} test_romsjedi_model testinput/model.yaml
  ${MPIrun} ../../bin/romsjedi_forecast.x testinput/forecast_roms.yaml
  ${MPIrun} ../../bin/romsjedi_error_covariance_training.x testinput/parameters_bump_cor_nicas.yaml
  ${MPIrun} test_romsjedi_errorcovariance testinput/errorcovariance.yaml
  ${MPIrun} test_romsjedi_linearmodel testinput/linearmodel.yaml
fi

exit 0
