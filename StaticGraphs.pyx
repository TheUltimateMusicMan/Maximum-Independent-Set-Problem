# -*- coding: utf-8 -*-
"""
Created on Sun Apr  5 11:35:18 2026

@author: Scott
"""

cimport cython
cimport numpy as np
from cython.parallel cimport prange

from libc.stdlib cimport malloc, free
from libc.stdlib cimport rand, srand, RAND_MAX
from libc.time cimport time

import Graph_utilities as gutil
import numpy as np

srand(<unsigned int> time(NULL))





cdef randint(int a, int b):
    
    cdef unsigned long long r
    cdef int N = b - a + 1
    r = ((<unsigned long long>rand()) << 32) | rand()  # 64-bit number
    return a + <int>(r % N)


def random_int(int a, int b): # accessible from Python
    return randint(a, b)


cdef class StaticGraph:
    
    '''
    This class of graphs is a class of graphs that cannot be modified after
    creation. These are only meant to be studied for certain NP-hard problems,
    such as finding the largest independent set.
    '''
    
    cdef public list vertices
    cdef public list edges
    cdef public list adjacency
    cdef public bool digraph
    cdef public dict coloring
    cdef public dict inv_coloring
    cdef public int[:] sequence
    cdef int num_vertices
    cdef int num_edges
    
    cdef int[:] start_indices
    cdef int[:] adj_lengths
    cdef int[:] static_adj
    
    cdef bool smart_mode
    
    cdef public unsigned char[:] forbidden # private attribute used in some methods
    
    def __init__(self, graph_data, graph_format = "standard"):
        
        '''Initialize a graph using either tuple format or adjacency format.
        
        Parameters:
            graph_format: str. The format of the graph. Either "standard" or "neighbor".
            
            graph_tuple: optional tuple(list, list). If your graph format is standard, include this tuple.
            
            graph_adjacency: optional dict{str: list}. If your graph format is neighbor, include this dictionary.
        '''
        
        if graph_format == "standard":
            self.vertices, self.edges = graph_data
            
        elif graph_format == "neighbor":
            self.vertices, self.edges = ([], [])
            
            for vertex in graph_data:
                self.vertices.append(vertex)
                
                for other_endpoint in graph_data[vertex]:
                    
                    if not((vertex, other_endpoint) in self.edges or \
                           (other_endpoint, vertex) in self.edges):
                        
                        self.edges.append((vertex, other_endpoint))
                        
        else: # recognize as standard.
            self.vertices, self.edges = graph_data
        
        self.num_vertices = len(self.vertices)
        self.num_edges = len(self.edges)
        
        self.static_adj = np.zeros(2 * self.num_edges, dtype=np.int32)
        
        self.vertices.sort()
        
        self.digraph = True
        
        self.coloring = {}
        
        self.inv_coloring = {}
        
        self.adjacency = []
        
        self.start_indices = np.zeros(self.num_vertices, dtype=np.int32)
        self.adj_lengths = np.zeros(self.num_vertices, dtype=np.int32)
        
        for vertex in self.vertices:
            self.adjacency.append([])
        for edge in self.edges:
            a, b = edge
            self.adjacency[a].append(b)
            self.adjacency[b].append(a)
        
        cdef int[::1] neighbors
        
        for vertex in self.vertices:
            self.adjacency[vertex].sort()
            neighbors_arr = np.array(self.adjacency[vertex], dtype = np.int32)
            neighbors = neighbors_arr
            self.adjacency[vertex] = neighbors
        
        i = 0
        
        for vertex in self.vertices:
            self.start_indices[vertex] = i
            self.adj_lengths[vertex] = len(self.adjacency[vertex])
            for neighbor in self.adjacency[vertex]:
                self.static_adj[i] = neighbor
                i += 1
                
            
        
        cdef int N = len(self.vertices)
        
        # allocate raw C array
        cdef unsigned char* c_forbidden
        c_forbidden = <unsigned char*> malloc(N * sizeof(unsigned char))
        for i in range(N):
            c_forbidden[i] = 0  # initialize
        
        # wrap in memoryview
        self.forbidden = <unsigned char[:N]> c_forbidden
        
        
        cdef int[::1] vertex_sequence = np.array(self.vertices, dtype = np.int32)
        
        self.sequence = vertex_sequence
        
        self.smart_mode = False
        
    
    
    cdef find_start_neighbor_index(self, int [:] neighbors, int start_vertex):
        """
        Binary search for the index of a neighbor in neighbors that is the first one not yet eliminated (or forbidden). Specifically made
        for the independent set generating algorithm.
        """
        
        cdef int low = 0
        cdef int high = len(neighbors)
        cdef int midpoint
        
        while low < high:
            
            midpoint = (high + low) // 2
            
            if neighbors[midpoint] < start_vertex:
                low = midpoint + 1
            else:
                high = midpoint
        
        return low
    
    
    
    def deterministic_shuffle(self):
        '''
        This function scrambles the sequence attribute used for vertex-order
        dependent algorithms like greedy coloring and finding a large
        independent set. Much faster than shuffle_sequence because it uses
        parallel processing.
        
        Returns: None
        '''
        
        cdef int[:] sequence = self.sequence
        cdef int N = len(sequence)
        cdef int* seq_alloc = <int*> malloc(N * sizeof(int))
        cdef int[:] sequence_copy = <int[:N]> seq_alloc
        
        cdef int i, j, k
        cdef int temp
        
        cdef int offset = randint(0, N)
        
        with nogil:
            
            for i in prange(N):
                with cython.boundscheck(False), cython.wraparound(False):
                    sequence_copy[i] = sequence[i]
            
            for k in prange(0, N - 1, 2):
                with cython.boundscheck(False), cython.wraparound(False):
                    i = (sequence_copy[k] + offset) % N
                    j = (sequence_copy[k + 1] + offset) % N
                    temp = sequence[i]
                    sequence[i] = sequence[j]
                    sequence[j] = temp
        
        if N % 2 == 1:
            i = 0
            j = N
            temp = sequence[i]
            sequence[i] = sequence[j]
            sequence[j] = temp
        
        free(seq_alloc)
        
    
    def shuffle_sequence(self):
        '''
        This function scrambles the sequence attribute used for vertex-order
        dependent algorithms like greedy coloring and finding a large
        independent set.
        
        Returns: None
        '''
        
        cdef int[:] sequence = self.sequence
        cdef int N = len(sequence)
        cdef int i, j
        cdef int temp
        
        for i in range(N - 1):
            j = randint(i, N - 1)
            temp = sequence[i]
            sequence[i] = sequence[j]
            sequence[j] = temp
            
    
    def find_large_ind_set(self, sequence_input = None, return_type = "size", organize = 0):
        '''
        sequence: a Python list of vertices containing the order in which to perform
        the vertex selection in.
        
        Returns: list[int]
        '''
        
        cdef int[:] sequence # cython memoryview sequence for fast access to elements
        cdef int[::1] seq_array
        
        
        if sequence_input is None:
            sequence = self.sequence
        else:
            seq_array = np.array(sequence_input, dtype=np.int32)
            sequence = seq_array
        
        
        #cython-type variables
        cdef int N = len(sequence)
        cdef int i = 0
        cdef int j
        cdef unsigned char[:] forbidden = self.forbidden
        cdef unsigned char true = 1 - forbidden[0] # true is the boolean variable storing the target truth for being forbidden.
        cdef int vertex
        cdef int min_vertex = 0
        cdef int max_vertex = N - 1
        cdef int[:] neighbors
        
        cdef int[:] flat_adjacency = self.static_adj
        cdef int[:] start_inds = self.start_indices
        cdef int[:] adj_lengths = self.adj_lengths
        
        cdef int start_ind
        cdef int skipped_start_ind
        cdef int adj_len
        cdef int neighbor
        cdef int temp
        
        cdef int[:] ind_array = np.empty(N, dtype=np.int32)
        cdef int ind_size = 0
        cdef unsigned char organize_ind_set = organize
        
        
        while i < N:
            vertex = sequence[i]
            forbidden[vertex] = true
            ind_array[ind_size] = vertex
            ind_size += 1
            
            if organize_ind_set == 1: # move the independent set vertex to the beginning of sequence
                temp = sequence[i]
                sequence[i] = sequence[ind_size]
                sequence[ind_size] = temp
            
            start_ind = start_inds[vertex] # starting index for adjacency of vertex in flat_adjacency
            adj_len = adj_lengths[vertex]
            neighbors = flat_adjacency[start_ind:start_ind + adj_len] # neighbors is sorted thanks to code in the graph initialization method
            
            if self.smart_mode:
                skipped_start_ind = self.find_start_neighbor_index(neighbors, min_vertex)
                neighbors = neighbors[skipped_start_ind:]
            
            j = 0
            
            with nogil:
                for j in prange(adj_len, schedule='static'):
                    with cython.boundscheck(False), cython.wraparound(False):
                        neighbor = neighbors[j]
                        forbidden[neighbor] = true
            
            i += 1
            while i < N and forbidden[sequence[i]] == true: # skip to the next non-forbidden vertex.
                i += 1
            
            if self.smart_mode:
                while min_vertex < N and max_vertex > 0 and (forbidden[min_vertex] == true or forbidden[max_vertex] == true):
                    if forbidden[min_vertex] == true:
                        min_vertex += 1
                    if forbidden[max_vertex] == true:
                        max_vertex -= 1
        
        
        if return_type == "set":
            ind_set = []
            
            for i in range(ind_size):
                ind_set.append(ind_array[i])
        
            return ind_set
        
        else:
            return ind_size
            
    
    
#    def welsh_powell_color(self, starting_v = None, adjacency = None):