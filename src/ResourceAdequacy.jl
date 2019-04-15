module ResourceAdequacy

using Dates
using Decimals
using Distributions
using MinCostFlows
using OnlineStats
using Random
using Future # for randjump
using StatsBase

import Base: -

export

    -,

    assess,

    # Units
    Year, Month, Week, Day, Hour, Minute,
    MW, GW,
    MWh, GWh, TWh,

    # Metrics
    LOLP, LOLE, EUE, ExpectedInterfaceFlow, ExpectedInterfaceUtilization,
    val, stderror,

    # Distribution extraction specifications
    Backcast, REPRA,

    # Simulation specifications
    NonSequentialCopperplate, SequentialCopperplate,
    NonSequentialNetworkFlow, SequentialNetworkFlow,

    # Result specifications
    Minimal, Spatial, Temporal, SpatioTemporal, Network


# Basic / common functionality
include("utils/utils.jl")
include("systemdata/systemdata.jl")
include("metrics/metrics.jl")
include("abstractspecs/abstractspecs.jl")
include("simulations/sequentialutils.jl")

# Spec instances
spec_instances = [
    ("extraction", ["backcast", "repra"]),
    ("simulation", ["nonsequentialcopperplate", "sequentialcopperplate",
                    "nonsequentialnetworkflow", "sequentialnetworkflow"]),
    ("result", ["minimal", "temporal", "spatial", "spatiotemporal", "network"])
]
for (spec, instances) in spec_instances, instance in instances
    include(spec * "s/" * instance * ".jl")
end

include("simulations/flowproblems.jl")

end # module
