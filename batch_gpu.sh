#!/bin/bash
#SBATCH -J USERNAME
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=16:00:00
#SBATCH --mem=2000M
#SBATCH --gres=gpu:1
#SBATCH --partition=gpu2
#SBATCH --exclusive

RESULTS=results
mkdir -p ${RESULTS}

module purge
module load pgi/17.1 cuda

#warmup
srun --gpufreq=2505:823 popcorn2d_kepler $RESULTS/512x512_it64_r20_pgi_k80 0.0 0.001 400 512 512 20
srun --gpufreq=2505:823 popcorn2d_kepler $RESULTS/512x512_it64_r20_pgi_k80 0.0 0.001 400 512 512 20
