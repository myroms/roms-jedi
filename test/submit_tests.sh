#!/bin/bash

#######################################################################
## Batch script to run ROMS-JEDI testa cases with SLURM               #
#######################################################################

##  SLURM configuration for orion:
##
##  Use 'sbatch submit_tests.sh'                to queue the job
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
#SBATCH  --account=marine-cpu             # NOAA's Allocation
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

export OOPS_TRACE=1
export OOPS_DEBUG=1

 srun ./test_roms_geometry ./testinput/geometry.yml
 srun ./test_roms_state ./testinput/state.yml
