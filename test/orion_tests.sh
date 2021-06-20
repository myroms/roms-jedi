#!/bin/bash

#######################################################################
## Batch script to run ROMS-JEDI Unit Test Cases with SLURM in ORION  #
##                                                                    #
## THIS SCRIPT NEEDS TO BE RUN FROM:                                  #
##                                                                    #
##      <root-dir>/roms-jedi/build/roms-jedi                          #
##                                                                    #
#######################################################################

##  SLURM configuration for orion:
##
##  Use 'sbatch orion_tests.sh'                 to queue the job NOAA's ORION HPC
##  Use 'squeue -u harango'                     to check our group jobs (including JOBID)
##  Use 'sacct -j JOBID -l'                     to check job accounting data
##  Use 'scontrol show job JOBID'               to check job configuration
##  Use 'sinfo JOBID'                           to check job information
##  Use 'scancel JOBID'                         to cancel a job

##SBATCH --exclusive                      # don't run on nodes with other jobs running
#SBATCH  --partition=debug                # Partition (job queue), short runs (30 min max)
##SBATCH --partition=orion                # Partition (job queue), long runs
#SBATCH  --qos=debug                      # mid priority (30 min max)
##SBATCH --qos=windfall                   # Low priority NOAA jobs (no time limit)
#SBATCH  --account=marine-cpu             # NOAA's ORION Allocation
#SBATCH  --job-name=ROMSjedi              # Assign an short name to your job
#SBATCH  --nodes=1                        # Number of nodes you require (each has 32 PETs)
#SBATCH  --ntasks=2                       # Total number of tasks you'll launch
#SBATCH  --ntasks-per-node=2              # Number of tasks you'll launch on each node
#SBATCH  --cpus-per-task=1                # Cores per task (>1 if multithread tasks)
#SBATCH  --mem=1000                       # Real memory (RAM) required (MB)
#SBATCH  --time=00-00:05:00               # Total run time limit (DD-HH:MM:SS)
#SBATCH  --output=log.tests               # STDOUT output file
#SBATCH  --error=err.tests                # STDERR output file (optional)
#SBATCH  --export=ALL                     # Export you current env to the job env

export OOPS__TRACE=1
export MAIN_DEBUG=1
export OOPS_DEBUG=1

source /etc/bashrc
module purge
export JEDI_OPT=/work/noaa/da/grubin/opt/modules
module use $JEDI_OPT/modulefiles/core
module load jedi/intel-impi
module list
ulimit -s unlimited

export SLURM_EXPORT_ENV=ALL
export HDF5_USE_FILE_LOCKING=FALSE


# Run all avialable or specific tests

 ALL_TEST=0         # Run specific tests. Then, check ./log.tests
#ALL_TEST=1         # Run all tests. Then, check ./Testing/Temporary/LastTest.log or
                    #                            ./Testing/Temporary/LastTestsFailed.log

if [ ${ALL_TEST} -eq 1 ]; then
  ctest -E get_
else
  cd test
  srun --ntasks=2 --cpu_bind=core --distribution=block:block test_roms_geometry testinput/geometry.yml
  srun --ntasks=2 --cpu_bind=core --distribution=block:block test_roms_state testinput/state.yml
fi

exit 0
