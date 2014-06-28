%%
%% %CopyrightBegin%
%%
%% Copyright © 2013 Aggelos Giantsios
%%
%% Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
%% and associated documentation files (the “Software”), to deal in the Software without restriction, 
%% including without limitation the rights to use, copy, modify, merge, publish, distribute, 
%% sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
%% furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included 
%% in all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
%% TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
%% IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
%% CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
%%
%% %CopyrightEnd%
%%

%% @copyright 2013 Aggelos Giantsios
%% @author Aggelos Giantsios

%% ============================================================================
%% @doc Directed / Undirected Graphs
%%
%% <p>This module implements directed and undirected graphs that are either 
%% weighted or unweighted.</p>
%%
%% <p>It is basically syntactic sugar for the digraph module with added 
%% support for undirected graphs.</p>
%%
%% <h3>How to use</h3>
%% <p>The fastest way to create a graph is to load it from a file with <code>from_file/1</code>.
%% The file that contains the graph must have the following format.</p>
%% 
%% <ul>
%%   <li>The 1st line will consist of four terms separeted by a white space.
%%     <ul>
%%       <li>1st Term: Positive Integer N that denotes the number of vertices</li>
%%       <li>2nd Term: Positive Integer M that denotes the number of edges.</li>
%%       <li>3rd Term: Atom <code>directed</code> or <code>undirected</code> that denotes the type of the graph.</li>
%%       <li>4th Term: Atom <code>unweighted</code> or <code>d</code> or <code>f</code> that denotes the type of the edge weights.
%%         <ul>
%%           <li><code>unweighted</code> is for an unweighted graph.</li>
%%           <li><code>d</code> is for decimal integer weights.</li>
%%           <li><code>f</code> is for floating point number weights in proper Erlang syntax.</li>
%%         </ul>
%%       </li>
%%     </ul>
%%   </li>
%%   <li>The next M lines will consist of the edge descriptions. 
%%       Each line will contain three terms : U V W. 
%%       This will denote an edge from U to V with W weight (W applies only if the graph is weighted).</li>
%% </ul>
%% 
%% <h3>Alternative syntax</h3>
%% <p>There is also the ability to explicitly state the vertices of the graph and load the graph with <code>from_file/3</code>.
%% In this case the above format is amended as follows:</p>
%% 
%% <ul>
%%   <li>
%%     The 1st line remains unchanged.
%%   </li>
%%   <li>
%%     The 2nd line consists of the vertices. The user will provide a function that will parse this line and return
%%     a list of the vertices. The spec of this function is 
%%     <code>fun(file:io_device(), integer()) -> [vertex()].</code>
%%   </li>
%%   <li>
%%     The next M lines that consist of the edge descriptions remain unchanged.
%%     However, the user will provide a function that will parse each line and return
%%     the three required terms : U V W. The spec of this function is
%%     <code>fun(file:io_device(), weighttype()) -> {vertex(), vertex(), weight()}.</code>
%%   </li>
%% </ul>
%% 
%% <p>For examples you can check the files in the test_data directory.</p>
%% 

-module(graph).

-export([from_file/1, from_file/3, del_graph/1, vertices/1, edges/1, edge_weight/2,
         edges_with_weights/1, out_neighbours/2, num_of_vertices/1,
         num_of_edges/1, pprint/1, empty/1, add_vertex/2, add_edge/3,
         add_edge/4, graph_type/1, del_edge/2]).

-export_type([graph/0, vertex/0, edge/0, weight/0]).

%%
%% @type graph(). A directed or undirected graph.
%% <p>It is wrapper for a digraph with the extra information on its type.</p>
%%
-record(graph, {type :: graphtype(), graph :: digraph:graph()}).
-type graph()      :: #graph{}.
-type vertex()     :: term().
-type edge()       :: {vertex(), vertex()}.
-type graphtype()  :: directed | undirected.
-type weight()     :: number().
-type weighttype() :: unweighted | d | f.


%% @doc Create a new empty graph.
-spec empty(graphtype()) -> graph().

empty(Type) when Type =:= directed; Type =:= undirected ->
  #graph{type=Type, graph=digraph:new()}.

%% @doc Create a new graph from a file using the default behaviour.
-spec from_file(file:name()) -> graph().

from_file(File) ->
  from_file(File, fun read_vertices/2, fun read_edge/2).

%% @doc Create a new graph from a file using a custo behaviour.
%% <p>The user must provide the 2 functions for reading the vertices and the
%% edge descriptions.</p>
%%
%% <p>ReadVertices will take the file descriptor and the number of vertices and
%% return the list of the vertices.</p>
%%
%% <p>ReadEdge will take the file descriptor and the type of the weights of the graph and
%% return the tuple {V1, V2, W}, where V1 is the start of the edge, V2 is the end of the edge 
%% and W is the weight of the edge (for unweighted graphs the edge must be 1).</p>
-spec from_file(file:name(), function(), function()) -> graph().

from_file(File, ReadVertices, ReadEdge) ->
  {ok, IO} = file:open(File, [read]),
  %% N = Number of Vertices :: non_neg_integer()
  %% M = Number of Edges :: non_neg_integer()
  %% T = Graph Type :: directed | undirected
  %% W = Edge Weight weighted :: Weight Type (d | f) | unweighted
  {ok, [N, M, T, W]} = io:fread(IO, ">", "~d ~d ~a ~a"),
  G = #graph{type=T, graph=digraph:new()},
  ok = init_vertices(IO, G, N, ReadVertices),
  ok = init_edges(IO, G, M, ReadEdge, T, W),
  G.

%% @doc Default function for reading the vertices from a file.
%% <p>The default behaviour is that, given the number of vertices, each vertex
%% is assigned to an integer.</p>
-spec read_vertices(file:io_device(), integer()) -> [integer()].

read_vertices(_IO, N) -> lists:seq(0, N-1).

%% @doc Default function for reading the edge description from a file.
%% <p>The default behaviour is that the edge description is a line that containts 
%% three terms: U V W (W applies only to weighted graphs).</p>
%%
%% <p>U is the integer that denotes the start of the edge.</p>
%% <p>V is the integer that denotes the end of the edge.</p>
%% <p>W is the number that denotes the weight of the edge.</p>
-spec read_edge(file:io_device(), weighttype()) -> {vertex(), vertex(), weight()}.

read_edge(IO, unweighted) ->
  {ok, [V1, V2]} = io:fread(IO, ">", "~d ~d"),
  {V1, V2, 1};
read_edge(IO, WT) ->
  Format = "~d ~d ~" ++ atom_to_list(WT),
  {ok, [V1, V2, W]} = io:fread(IO, ">", Format),
  {V1, V2, W}.


%% Initialize the vertices of the graph
-spec init_vertices(file:io_device(), graph(), integer(), function()) -> ok.

init_vertices(IO, Graph, N, ReadVertices) ->
  Vs = ReadVertices(IO, N),
  lists:foreach(fun(V) -> add_vertex(Graph, V) end, Vs).

%% Initialize the edges of the graph
-spec init_edges(file:io_device(), graph(), integer(), function(), graphtype(), weighttype()) -> ok.

init_edges(_IO, _G, 0, _ReadEdge, _T, _WT) -> ok;
init_edges(IO, G, M, ReadEdge, T, WT) ->
  {V1, V2, W} = ReadEdge(IO, WT),
  _ = init_edge(G, T, V1, V2, W),
  init_edges(IO, G, M-1, ReadEdge, T, WT).

-spec init_edge(graph(), graphtype(), vertex(), vertex(), weight()) -> edge().

init_edge(G, directed, V1, V2, W) ->
  add_edge(G, V1, V2, W);
init_edge(G, undirected, V1, V2, W) ->
  _ = add_edge(G, V1, V2, W),
  add_edge(G, V2, V1, W).


%% @doc Delete a graph
-spec del_graph(graph()) -> 'true'.
  
del_graph(G) ->
  digraph:delete(G#graph.graph).
  
%% @doc Return the type of the graph.
-spec graph_type(graph()) -> graphtype().
  
graph_type(G) ->
  G#graph.type.

%% @doc Add a vertex to a graph
-spec add_vertex(graph(), vertex()) -> vertex().

add_vertex(G, V) ->
  digraph:add_vertex(G#graph.graph, V).
  
%% @doc Return a list of the vertices of a graph
-spec vertices(graph()) -> [vertex()].
  
vertices(G) ->
  digraph:vertices(G#graph.graph).

%% @doc Return the number of vertices in a graph
-spec num_of_vertices(graph()) -> non_neg_integer().
  
num_of_vertices(G) ->
  digraph:no_vertices(G#graph.graph).
  
%% @doc Add an edge to an unweighted graph.
-spec add_edge(graph(), vertex(), vertex()) -> edge().

add_edge(G, From, To) ->
  add_edge(G, From, To, 1).
  
%% @doc Add an edge to a weighted graph
-spec add_edge(graph(), vertex(), vertex(), weight()) -> edge() | {error, not_numeric_weight}.

add_edge(G, From, To, W) when is_number(W) -> 
  digraph:add_edge(G#graph.graph, {From, To}, From, To, W);
add_edge(_G, _From, _To, _W) ->
  {error, not_numeric_weight}.
  
%% @doc Delete an edge from a graph
-spec del_edge(graph(), edge()) -> 'true'.

del_edge(G, E) ->
  digraph:del_edge(G#graph.graph, E).
  
%% @doc Return a list of the edges of a graph
-spec edges(graph()) -> [edge()].
  
edges(G) ->
  Es = digraph:edges(G#graph.graph),
  case G#graph.type of
    'directed' ->
      Es;
    'undirected' ->
      remove_duplicate_edges(Es, [])
  end.

%% Remove the duplicate edges of a undirected graph
remove_duplicate_edges([], Acc) ->
  Acc;
remove_duplicate_edges([{From, To}=E|Es], Acc) ->
  remove_duplicate_edges(Es -- [{To, From}], [E|Acc]).

%% @doc Return the number of edges in a graph
-spec num_of_edges(graph()) -> non_neg_integer().
  
num_of_edges(G) ->
  M = digraph:no_edges(G#graph.graph),
  case G#graph.type of
    'directed'   -> M;
    'undirected' -> M div 2
  end.
  
%% @doc Return the weight of an edge
-spec edge_weight(graph(), edge()) -> weight() | 'false'.
  
edge_weight(G, E) ->
  case digraph:edge(G#graph.graph, E) of
    {E, _V1, _V2, W} -> W;
    'false' -> 'false'
  end.
  
%% @doc Return a list of the edges of a graph along with their weights
-spec edges_with_weights(graph()) -> [{edge(), weight()}].
  
edges_with_weights(G) ->
  Es = edges(G),
  lists:map(fun(E) -> {E, edge_weight(G, E)} end, Es).
  
%% @doc Return a list of the out neighbours of a vertex
-spec out_neighbours(graph(), vertex()) -> [vertex()].
  
out_neighbours(G, V) ->
  digraph:out_neighbours(G#graph.graph, V).
  
%% @doc Pretty print a graph
-spec pprint(graph()) -> 'ok'.
  
pprint(G) ->
  Vs = digraph:vertices(G#graph.graph),
  F = 
    fun(V) ->
      Es = digraph:out_edges(G#graph.graph, V),
      Ns = lists:map(
        fun(E) -> 
          {E, _V1, V2, W} = digraph:edge(G#graph.graph, E),
          {V2, W}
        end, 
        Es),
      {V, Ns}
    end,
  N = lists:sort(fun erlang:'<'/2, lists:map(F, Vs)),
  io:format("[{From, [{To, Weight}]}]~n"),
  io:format("========================~n"),
  io:format("~p~n", [N]).

