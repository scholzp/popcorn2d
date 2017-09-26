#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=40:00:00
#SBATCH --mem=2000M
#SBATCH --partition=haswell64
#SBATCH --exclusive

RESULTS=results
mkdir -p ${RESULTS}

# module purge
# module load pgi/17.1 cuda

#warmup
MP_BIND=no ./popcorn2d $RESULTS/512x512_it64_r20_pgi_haswell_1core 0.0 0.001 400 512 512 20
MP_BIND=no ./popcorn2d $RESULTS/512x512_it64_r20_pgi_haswell_1core 0.0 0.001 400 512 512 20

