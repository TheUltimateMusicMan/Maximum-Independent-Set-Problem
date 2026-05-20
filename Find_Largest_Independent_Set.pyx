
# cython: language_level = 3
# distutils: language=c++

# -*- coding: utf-8 -*-
"""
Created on Mon Mar 16 15:16:38 2026

@author: Scott
"""

cimport cython

from libcpp.vector cimport vector
from libcpp.pair cimport pair
from libcpp.random cimport mt19937 as randomizer
from libcpp.random cimport uniform_int_distribution as unint_dist
from libc.time cimport time

import StaticGraphs
import numpy as np

cdef unsigned int seed = <unsigned int>time(NULL)

cdef randomizer rng
rng.seed(seed)


# utility methods =============================================================

def random_pair(range_max):
    
    cdef int[2] pair
    i = StaticGraphs.random_int(0, range_max - 1)
    j = StaticGraphs.random_int(0, range_max - 1)
    pair[0] = i
    pair[1] = j
    
    return pair


def swap_items(int[:] items, int i, int j):
    cdef int temp = items[i]
    items[i] = items[j]
    items[j] = temp


def swap(items, i, j):
    items[i][j] = items[j][i]


def swap_random(items, times):
    for k in range(times):
        (i, j) = random_pair(len(items))
        items[i], items[j] = items[j], items[i]


def disorder(sequence, percentage):
    N = int(percentage * len(sequence))
    
    for i in range(N):
        i, j = random_pair(len(sequence))
        swap(sequence, i, j)

def shuffle(sequence, start_index = 0):
    
    sequence_length = len(sequence)
    new_sequence = []
    for i in range(start_index - 1):
        new_sequence.append(sequence[i])
    
    for i in range(start_index, sequence_length):
        new_sequence.append(sequence.pop(StaticGraphs.randint(start_index, len(sequence) - 1)))

    return new_sequence


def fast_shuffle(sequence, start_index = 0):
    
    for i in range(len(sequence)):
        swap(sequence, i, StaticGraphs.
             StaticGraphs.randint(i, len(sequence)) - 1)
    

def get_degrees(graph):
    degrees = {}
    for vertex in graph.vertices:
        degrees[vertex] = len(graph.adjacency[vertex])
    return degrees


def get_largest_degree(graph):
    max_degree = 0
    for vertex in graph.vertices:
        if len(graph.adjacency[vertex]) > max_degree:
            max_degree = len(graph.adjacency[vertex])
                             
    return max_degree


# main methods ================================================================


def find_large_ind_set_greedy_procedural_search(graph, depth, tries):
    
    sequence = graph.vertices.copy()
    fast_shuffle(sequence)
    
    l = 0
    max_ind_size = 0
    
    best_swap = (0, 0)
    
    distribution = {}
    
    while l < tries:
        
        m = 0
        d = 0
        swap(sequence, best_swap[0], best_swap[1]) # swap the best swap
        local_max_ind_size = 0
        
        while m < len(sequence) and l < tries and d < depth:
            
            n = m
            while n < len(sequence) and l < tries and d < depth:
                
                swap(sequence, m, n)
                ind_set = graph.find_independent_set_fast_version(sequence)
                
                if len(ind_set) in distribution:
                    distribution[len(ind_set)] += 1
                else:
                    distribution[len(ind_set)] = 1
                
                if len(ind_set) > local_max_ind_size:
                    local_max_ind_size = len(ind_set)
                    best_swap = (m, n)
                
                swap(sequence, m, n) # swap back
                
                l += 1
                n += 1
                d += 1
            
            m += 1
        
        if local_max_ind_size > max_ind_size:
            max_ind_size = local_max_ind_size
        
        
    print(distribution)
    
    return max_ind_size



def find_large_ind_set_procedural_search(graph, tries):
    
    sequence = graph.vertices.copy()
    fast_shuffle(sequence)
    
    l = 0
    max_ind_size = 0
    
    distribution = {}
    
    while l < tries:
        reset = False
        m = 0
        while m < len(sequence) and l < tries and not reset:
            
            n = m
            while n < len(sequence) and l < tries and not reset:
                
                swap(sequence, m, n)
                ind_set = graph.find_independent_set_fast_version(sequence)
                
                if len(ind_set) in distribution:
                    distribution[len(ind_set)] += 1
                else:
                    distribution[len(ind_set)] = 1
                
                if len(ind_set) > max_ind_size:
                    max_ind_size = len(ind_set)
                    reset = True
                else: # swap back
                    swap(sequence, m, n)
                
                l += 1
                n += 1
            
            m += 1
    
    print(distribution)
    
    return max_ind_size
                
                


def find_large_ind_set_random_walk(graph, stepsize, steps): # similar to random_greedy_walk, except we do not swap back if a swap leads to a worse size
    
    distribution = {}

    sequence = graph.vertices.copy()
    
    max_ind_size = 0
    
    sequence = shuffle(sequence)
    
    for k in range(steps):
        swap_random(sequence, stepsize)
        ind_set = graph.find_independent_set_fast_version(sequence)
        
        if len(ind_set) > max_ind_size:
            max_ind_size = len(ind_set)
        if len(ind_set) in distribution:
            distribution[len(ind_set)] += 1
        else:
            distribution[len(ind_set)] = 1
        
    print(distribution)
    return max_ind_size


def find_large_ind_set_sorted_sequence(graph): # sorts the sequence of vertices in ascending order of degree
    
    sequence = sorted(graph.vertices, key=lambda v: len(graph.adjacency[v]), reverse=True)
    ind_set = graph.find_independent_set_fast_version(sequence)
    return len(ind_set)


def find_large_ind_set_smart_selective_nomad_random_walk(graph, change_phase_time, sample_size, max_walk_steps, total_tries):
    
    sequence = graph.vertices.copy()
    
    phase = "nomadic"
    
    distribution = {}
    
    max_ind_size = 0
    
    best_mean = 0
    
    relocations = 0
    
    l = 0
    
    best_sequences = []
    
    while l < total_tries:
        
        if l >= change_phase_time and phase == "nomadic":
            phase = "localized"
            print("Entering localized phase")
        
        if phase == "nomadic":
            sequence = shuffle(sequence)
        else:
            sequence = best_sequences[-1].copy()
        
        
        walk_steps = 0
        
        mean_size = 0
        
        local_max_ind_size = 0
        
        while walk_steps < max_walk_steps: # walking phase
            (i, j) = random_pair(len(sequence))
            swap(sequence, i, j)
            ind_set = graph.find_independent_set_fast_version(sequence)
            
            if len(ind_set) > local_max_ind_size:
                local_max_ind_size = len(ind_set)
            else: # swap back
                swap(sequence, i, j)
            walk_steps += 1
            mean_size += len(ind_set) / sample_size
            
            l += 1
            
            if len(ind_set) in distribution:
                distribution[len(ind_set)] += 1
            else:
                distribution[len(ind_set)] = 1
            
            
            if phase == "nomadic":
            
                if walk_steps == sample_size and not mean_size > best_mean:
                    
                    relocations += 1
                    
                    if local_max_ind_size > max_ind_size:
                        max_ind_size = local_max_ind_size
                    
                        break # go and relocate again
                    
                elif walk_steps == sample_size and mean_size > best_mean:
                    best_mean = mean_size
                    best_sequences.append(sequence.copy())
                
                    print(best_mean)
            
            if local_max_ind_size > max_ind_size:
                max_ind_size = local_max_ind_size
    
    print(distribution)
    
    print(relocations)
    
    return max_ind_size


def find_large_ind_set_smart_nomad_random_walk_2(graph, sample_size, max_walk_steps, total_tries):
    
    sequence = graph.vertices.copy()
    
    distribution = {}
    
    max_ind_size = 0
    
    best_mean = 0
    
    relocations = 0
    
    l = 0
    
    while l < total_tries:
        sequence = shuffle(sequence)
        walk_steps = 0
        
        mean_size = 0
        
        local_max_ind_size = 0
        
        while walk_steps < max_walk_steps: # walking phase
            (i, j) = random_pair(len(sequence))
            swap(sequence, i, j)
            ind_set = graph.find_independent_set_fast_version(sequence)
            
            if len(ind_set) > local_max_ind_size:
                local_max_ind_size = len(ind_set)
            else: # swap back
                swap(sequence, i, j)
            walk_steps += 1
            mean_size += len(ind_set) / sample_size
            
            l += 1
            
            if len(ind_set) in distribution:
                distribution[len(ind_set)] += 1
            else:
                distribution[len(ind_set)] = 1
            
            if walk_steps == sample_size and not mean_size > best_mean:
                
                relocations += 1
                
                if local_max_ind_size > max_ind_size:
                    max_ind_size = local_max_ind_size
                
                    break # go and relocate again
                
            elif walk_steps == sample_size and mean_size > best_mean:
                best_mean = mean_size
                print(best_mean)
            
            if local_max_ind_size > max_ind_size:
                max_ind_size = local_max_ind_size
    
    print(distribution)
    
    print(relocations)
    
    return max_ind_size



def find_large_ind_set_smart_nomad_random_walk(graph, int sample_size, int max_walk_steps, int total_tries):
    
    cdef int N = len(graph.sequence)
    
    cdef int[:] sequence = graph.sequence
    
    cdef int max_ind_size = 0, relocations = 0, l = 0
    cdef long total = 0
    cdef int walk_steps, local_max_ind_size
    
    cdef double mean_size
    cdef int S
    
    cdef vector[int] size_dist = vector[int]()
    cdef vector[int] ind_set
    cdef int[2] index_pair
    
    for i in range(N):
        size_dist.push_back(0)
    
    while l < total_tries:
        
        graph.deterministic_shuffle()
        
        walk_steps = 0
        mean_size = 0.0
        local_max_ind_size = 0
        
        while walk_steps < max_walk_steps: # walking phase
            index_pair = random_pair(N)
            i = index_pair[0]
            j = index_pair[1]
            swap_items(sequence, i, j)
            S = graph.find_large_ind_set()
            
            if S > local_max_ind_size:
                local_max_ind_size = S
                
                size_dist[S] += 1
                    
            else: # swap back
                swap_items(sequence, i, j)
            walk_steps += 1
            mean_size += S / sample_size
            total += S
            l += 1
            

            
            if walk_steps == sample_size and not mean_size > total / l:
                
                relocations += 1
                
                if local_max_ind_size > max_ind_size:
                    max_ind_size = local_max_ind_size
                
                break # go and relocate again
            
            if local_max_ind_size > max_ind_size:
                max_ind_size = local_max_ind_size
    
    dist = {}
    
    for i in range(len(size_dist)):
        if size_dist[i] != 0:
            dist[i] = size_dist[i]
    
    print(dist)
    
    print(relocations)
    
    return max_ind_size


def find_large_ind_set_nomadic_random_greedy_walk_2(graph, int relocations, int walk_steps):
    """
    Comes with an improved localized search compared to the first nomadic random greedy walk.
    Instead of swapping two random vertices, we swap a random vertex in the independent set with a random vertex outside.
    Note that the independent set updates and is recorded in the sequence itself
    (all independent set vertices are clumped a the beginning of the sequence)
    """
    
    cdef int N = len(graph.sequence)
    cdef int[:] sequence = graph.sequence
    
    cdef int max_ind_size = 0
    cdef int local_max_ind_size
    cdef int S
    cdef int partition_index # used as a partition between the vertices in an independent set discovered after each relocation
    # or each improvement of a localized search step. It is the independent number of
    # the set generated by the current local best sequence.
    
    cdef int i, j
    
    for l in range(relocations):
        graph.deterministic_shuffle()
        local_max_ind_size = 0
        S = graph.find_large_ind_set(organize = 1)
        partition_index = S
        
        for k in range(walk_steps - 1):
            i = StaticGraphs.random_int(0, partition_index - 1)
            j = StaticGraphs.random_int(partition_index, N - 1)
            swap_items(sequence, i, j)
            S = graph.find_large_ind_set()
            
            if S > local_max_ind_size:
                graph.find_large_ind_set(organize = 1) # organize the sequence before the next step if there is an improvement
                local_max_ind_size = S
                partition_index = local_max_ind_size
        
        if local_max_ind_size > max_ind_size:
            max_ind_size = local_max_ind_size
    
    
        
    return max_ind_size


def find_large_ind_set_nomadic_random_greedy_walk(graph, int relocations, int walk_steps):
    
    """
    Periodically relocates by randomly shuffling the entire sequence at fixed intervals.
    """
    
    cdef int N = len(graph.sequence)
    cdef int[:] sequence = graph.sequence
    
    cdef int max_ind_size = 0
    cdef int local_max_ind_size
    cdef int S
    
    cdef int i, j
    
    cdef int[2] index_pair
    
    for l in range(relocations):
        graph.deterministic_shuffle()
        local_max_ind_size = 0
        
        for k in range(walk_steps):
            index_pair = random_pair(N)
            i = index_pair[0]
            j = index_pair[1]
            swap_items(sequence, i, j)
            S = graph.find_large_ind_set()
            
            if S > local_max_ind_size:
                local_max_ind_size = S
            else: # swap back
                swap_items(sequence, i, j)
            
        
        if local_max_ind_size > max_ind_size:
            max_ind_size = local_max_ind_size
    
    
        
    return max_ind_size


def find_large_ind_set_random_greedy_walk(graph, N): # my third iteration by swapping two vertices each time, then checking the independent size, then rejecting the swap if no improvement, then try another swap. It only walks in an improving direction.

    sequence = graph.vertices.copy()
    
    max_ind_size = 0
    
    sequence = shuffle(sequence)
    
    for k in range(N):
        (i, j) = random_pair(len(sequence))
        swap(sequence, i, j)
        ind_set = graph.find_independent_set_fast_version(sequence)
        
        if len(ind_set) > max_ind_size:
            max_ind_size = len(ind_set)
        else: # swap back
            swap(sequence, i, j)
        
    return max_ind_size


def find_large_ind_set_disorder(graph, N): # my second iteration using a better shuffling algorithm. Disorders the set with a number of swaps a fraction of the sequence length.
    
    sequence = graph.vertices.copy()
    
    max_ind_size = 0
    
    sequence = shuffle(sequence)
    
    for i in range(N):
        disorder(sequence, 0.5)
        ind_set = graph.find_independent_set_fast_version(sequence)
        if len(ind_set) > max_ind_size:
            max_ind_size = len(ind_set)
        
    return max_ind_size


def find_large_ind_set(graph, N): # my first iteration. Does a full shuffle of the sequence every time.
    
    sequence = graph.vertices.copy()
    
    max_ind_size = 0
    
    for i in range(N):
        sequence = shuffle(sequence)
        ind_set = graph.find_independent_set_fast_version(sequence)
        if len(ind_set) > max_ind_size:
            max_ind_size = len(ind_set)
        
    return max_ind_size


def find_large_ind_set_coloring(graph, trials):
    best_coloring = {}
    best_inv_coloring = {}
    largest_independent_size = 0
    
    V = graph.vertices
    
    for i in range(trials):
        
        vertex_order = shuffle(V.copy())
        coloring = StaticGraphs.graph.greedy_color(graph, sequence = vertex_order, adjacency = graph.adjacency)
        if len(graph.inv_coloring[0]) > largest_independent_size:
            largest_independent_size = len(graph.inv_coloring[0])
            best_inv_coloring = graph.inv_coloring
            best_coloring = coloring
    
        graph.inv_coloring = {}
    return largest_independent_size
