# -*- coding: utf-8 -*-
"""
Created on Sun Oct  5 16:27:32 2025

A bunch of private methods for graph functions in Graphs.py.

@author: Scott
"""

#private methods: =============================================================

def __tree_explore_next__(vertex, prev_vertex, vertices, adjacency, explored_vertices,\
                 tree_status):
    """ a recursive nonetype function that explores the graph. Input a
    starting vertex. This is a stack shell running for each vertex currently
    explored in a path from the starting vertex."""
    print("stack")
    
    if vertex not in explored_vertices: # prevent multiple paths reaching this vertex so the vertex is only added once
        explored_vertices.add(vertex)
    
    #if tree_status is false, return None to end the stack.
    if not tree_status[0]:
        return None
    
    #search all neighbors of vertex
    neighbors = []
    
    for neighbor in adjacency[vertex]:
        
            if neighbor != prev_vertex:
                if neighbor in explored_vertices: # cycle found
                    tree_status[0] = False
                    return None
                else:    
                    neighbors.append(neighbor)
        
    #if there are no neighbors of vertex, return None
    #to end this stack because we reached a leaf.
    print(neighbors)
    
    if len(neighbors) == 0:
        return None
    
    
    #otherwise, for each neighbor,
    
        #if tree_status is [false], return None to end the stack.
        #call the next stack shell explore_next(neighbor).
    
    else:
        for neighbor in neighbors:
            print("neighbor: " + str(neighbor))
            if not tree_status[0]:
                return None
            
            __tree_explore_next__(neighbor, vertex, vertices, adjacency, \
                                  explored_vertices, tree_status)


def __conn_explore_next__(vertex, vertices, adjacency, explored_vertices):
    """ a recursive nonetype function that explores the graph. Input a
    starting vertex. This is a stack shell running for each vertex currently
    explored in a path from the starting vertex."""
    print("stack")
    print(vertex)
    if vertex not in explored_vertices: # prevent multiple paths reaching this vertex so the vertex is only added once
        explored_vertices.add(vertex)
    
    #search all neighbors of vertex
    neighbors = adjacency[vertex]
    
    
        
    #if there are no neighbors of vertex, delete this vertex and return None
    #to end this stack because we reached a leaf.
    
    if len(neighbors) == 0:
        
        return None
    
    #otherwise, for each neighbor,
        
        #call the next stack shell explore_next(neighbor).
    
    else:
                
        for neighbor in neighbors:
            
            if neighbor not in explored_vertices:
                
                __conn_explore_next__(neighbor, vertices, adjacency, \
                                      explored_vertices)


def __bipartite_explore_next__(vertex, color_map, vertices,\
                 adjacency, explored_vertices, bipartite_status, color):
    
    """vertex is the current vertex, prev_vertex is the last vertex in the
    path chain, color_map is the bipartite coloring of the graph, vertices
    is the set of unexplored vertices, edges is the set of edges, and
    bipartite_status contains the bipartite status for all stacks to see.
    color is 1 or -1."""
    
    print("stack")
    #color the current vertex.
    #find all neighbors of the vertex that is not the previous vertex.
    
    color_map[vertex] = color
    
    if vertex not in explored_vertices: # prevent multiple paths reaching this vertex so the vertex is only added once
        explored_vertices.add(vertex)
    
    neighbors = adjacency[vertex]
    
    #if no neighbors are found, delete the current vertex and end this stack
    
    if len(neighbors) == 0:
        vertices.remove(vertex)
        return None
    
    #for each neighbor:
        #if bipartite_status is false, end this stack now.
            
        #call next stack explore_next with neighbor as the next vertex,
        #current vertex as the previous vertex, same color map, vertices,
        #edges, bipartite status, and opposite color.
    
    for neighbor in neighbors:
        
        if not bipartite_status[0]:
           return None
       
        else:
            if neighbor in explored_vertices:
                
                if color_map[neighbor] == color: # adjacent to vertex of same color
                    bipartite_status[0] = False
                    return None
            
            else:
                
                __bipartite_explore_next__(neighbor, color_map, vertices, \
                                           adjacency, explored_vertices, \
                                           bipartite_status, -color)
        
    #delete current vertex
    vertices.remove(vertex)
