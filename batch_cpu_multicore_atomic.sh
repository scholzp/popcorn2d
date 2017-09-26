#!/bin/bash
#SBATCH -J USERNAME
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --time=25:00:00
#SBATCH --exclusive
#SBATCH --mem=2000M
#SBATCH --partition=haswell64

RESULTS=results
mkdir -p ${RESULTS}

module purge
module load pgi/17.1

# warmup
./atomic/popcorn2d_multicore $RESULTS/512x512_it64_r20_pgi_haswell_24core_atomic 0.0 0.001 400 512 512 20
./atomic/popcorn2d_multicore $RESULTS/512x512_it64_r20_pgi_haswell_24core_atomic 0.0 0.001 400 512 512 20
