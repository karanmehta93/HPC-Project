#include <stdlib.h>
#include <stdio.h>
#include <iostream>
#include "gputimer.h"

#define MAX_THREADS 1024
using namespace std;
GpuTimer timer;

__global__ void getShortestPath(int *leastEnergySum, int * indexLeastEnergySumInRow, const int height, const int width) {

	/*printf("d1: %d \n", leastEnergySum[1638304]);
	printf("d2: %d \n", leastEnergySum[1638399]);

	if (leastEnergySum[1638304] <= leastEnergySum[1638399]) {
		printf("correct1 \n");
	}

	if (leastEnergySum[1638399] <= leastEnergySum[1638304]) {
		printf("correct2 \n");
	}*/

	int indexLeastEnergySumPath;
	int leastEnergySumPathValue = INT_MAX;
	for (int i = width * (height - 1); i < height * width; i++) {
		if (leastEnergySumPathValue >= leastEnergySum[i]) {
			leastEnergySumPathValue = leastEnergySum[i];
			indexLeastEnergySumPath = i;
		}
	}

	int tempCountHeight = height - 1;
	int tempIndexLeastEnergySumPath = indexLeastEnergySumPath;
	indexLeastEnergySumInRow[tempCountHeight] = indexLeastEnergySumPath;
	while (tempCountHeight > 0) {
		int left = tempIndexLeastEnergySumPath - width - 1;
		int middle = tempIndexLeastEnergySumPath - width;
		int right = tempIndexLeastEnergySumPath - width + 1;
		int leftLimit = (tempCountHeight - 1) * width;
		int rightLimit = tempCountHeight * width;
		if (leftLimit <= left && right < rightLimit) {
			if (leastEnergySum[left] <= leastEnergySum[middle] && leastEnergySum[left] <= leastEnergySum[right])
				tempIndexLeastEnergySumPath = left;
			else if (leastEnergySum[middle] <= leastEnergySum[left] && leastEnergySum[middle] <= leastEnergySum[right])
				tempIndexLeastEnergySumPath = middle;
			else if (leastEnergySum[right] <= leastEnergySum[middle] && leastEnergySum[right] <= leastEnergySum[left])
				tempIndexLeastEnergySumPath = right;
		} else if (leftLimit > left) {
			tempIndexLeastEnergySumPath = leastEnergySum[middle] <= leastEnergySum[right] ? middle : right;
		} else {
			tempIndexLeastEnergySumPath = leastEnergySum[left] <= leastEnergySum[middle] ? left : middle;
		}
		tempCountHeight--;
		indexLeastEnergySumInRow[tempCountHeight] = tempIndexLeastEnergySumPath;
	}
}

int main(int argc, char** argv) {

	int height = 0, width = 0;
	FILE* docRead = fopen("pathIndex", "rb");
	if (!docRead) {
		cout << "pathIndex file not found" << endl;
	}
	fread(&height, sizeof(int), 1, docRead);
	int* testIndexPath = (int *) malloc(height * sizeof(int));
	fread(testIndexPath, sizeof(int), height, docRead);
	fclose(docRead);

	FILE* docRead3 = fopen("minEnergy", "rb");
	if (!docRead3) {
		cout << "minEnergy file not found" << endl;
	}
	fread(&height, sizeof(int), 1, docRead3);
	fread(&width, sizeof(int), 1, docRead3);
	int * h_minEnergy = (int *) malloc(width * height * sizeof(int));
	fread(h_minEnergy, sizeof(int), width * height, docRead3);
	fclose(docRead3);

	cudaError_t rc;
	int *d_minEnergy;
	int *h_shortestPath, *d_shortestPath;
	h_shortestPath = (int *) malloc(height * sizeof(int));

	rc = cudaMalloc((void**) &d_shortestPath, height * sizeof(int));
	if (rc != cudaSuccess) {
		cout << "Malloc Failed for d_shortestPath" << endl;
	}

	rc = cudaMalloc((void**) &d_minEnergy, height * width * sizeof(int));
	if (rc != cudaSuccess) {
		cout << "Malloc Failed for d_minEnergy" << endl;
	}

	rc = cudaMemcpy(d_minEnergy, h_minEnergy, height * width * sizeof(int), cudaMemcpyHostToDevice);
	if (rc != cudaSuccess) {
		cout << "Memcpy failed from host to device" << endl;
	}

	timer.Start();
	getShortestPath<<<1,1>>>(d_minEnergy, d_shortestPath, height, width);
	timer.Stop();

	rc = cudaMemcpy(h_shortestPath, d_shortestPath, height * sizeof(int), cudaMemcpyDeviceToHost);
	if (rc != cudaSuccess) {
		cout << "Memcpy failed from device to host with rc:" << rc << endl;
	}

	cout << "time taken for the operation:" << timer.Elapsed() << endl;

	for (int i = height-1; i > 0; i--) {
		if (h_shortestPath[i] != testIndexPath[i]) {
			cout << "error at index:" << i << "|Expected: " << testIndexPath[i] << "|actual: " << h_shortestPath[i] << endl;
			break;
		}
	}

	/*int debug = 1;

	if (debug) {
		cout << h_minEnergy[1638304] << endl;
		cout << h_minEnergy[1638399] << endl;
	}*/



	cudaFree(d_shortestPath);
	cudaFree(d_minEnergy);
	free(h_minEnergy);
	free(testIndexPath);
	return 0;
}