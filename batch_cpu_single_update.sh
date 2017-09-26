#!/bin/bash
#SBATCH -J USERNAME
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

# 1cpu: 400ms x 20runs x 400talphas = ~3200s = 53min
#warmup
MP_BIND=no srun ./popcorn2d $RESULTS/512x512_it64_r20_pgi_haswell_1core_update 0.0 0.001 400 512 512 20
MP_BIND=no srun ./popcorn2d $RESULTS/512x512_it64_r20_pgi_haswell_1core_update 0.0 0.001 400 512 512 20

#./release/popcorn2d_gcc $RESULTS/256x256_it64_r20_gcc5_haswell_1core 0.0 0.001 400
