"""

    SystemModel(filename::String)

Load a `SystemModel` from an appropriately-formatted HDF5 file on disk.
"""
function SystemModel(inputfile::String)

    system = h5open(inputfile, "r") do f::HDF5File

        version, versionstring = readversion(f)
        println("$versionstring = $version")

        # Determine the appropriate version of the importer to use
        return if (0,2,0) <= version < (0,4,0)
            systemmodel_0_3(f)
        else
            @error("File format $versionstring not supported by this version of PRASBase.")
        end

    end

    return system

end


function systemmodel_0_3(f::HDF5File)

    metadata = attrs(f)

    start_timestamp = ZonedDateTime(read(metadata["start_timestamp"]),
                                    dateformat"yyyy-mm-ddTHH:MM:SSz")

    N = read(metadata["timestep_count"])
    L = read(metadata["timestep_length"])
    T = timeunits[read(metadata["timestep_unit"])]
    P = powerunits[read(metadata["power_unit"])]
    E = energyunits[read(metadata["energy_unit"])]

    timestamps = range(start_timestamp, length=N, step=T(L))

    has_regions = exists(f, "regions")
    has_generators = exists(f, "generators")
    has_storages = exists(f, "storages")
    has_generatorstorages = exists(f, "generatorstorages")
    has_interfaces = exists(f, "interfaces")
    has_lines = exists(f, "lines")

    has_regions ||
        error("Region data must be provided")

    has_generators || has_generatorstorages ||
        error("Generator or generator storage data (or both) must be provided")

    xor(has_interfaces, has_lines) &&
        error("Both (or neither) interface and line data must be provided")

    regionnames = readvector(f["regions/_core"], "name")
    regions = Regions{N,P}(
        regionnames,
        Int.(read(f["regions/load"]))
    )
    regionlookup = Dict(n=>i for (i, n) in enumerate(regionnames))
    n_regions = length(regions)

    if has_generators

        gen_names, gen_categories, gen_regionnames = readvector.(
            Ref(f["generators/_core"]), ["name", "category", "region"])

        gen_regions = getindex.(Ref(regionlookup), gen_regionnames)
        region_order = sortperm(gen_regions)

        generators = Generators{N,L,T,P}(
            gen_names[region_order], gen_categories[region_order],
            Int.(read(f["generators/capacity"]))[region_order, :],
            read(f["generators/failureprobability"])[region_order, :],
            read(f["generators/repairprobability"])[region_order, :]
        )

        region_gen_idxs = makeidxlist(gen_regions[region_order], n_regions)

    else

        generators = Generators{N,L,T,P}(
            String[], String[], zeros(Int, 0, N),
            zeros(Float64, 0, N), zeros(Float64, 0, N))

        region_gen_idxs = fill(1:0, n_regions)

    end

    if has_storages

        stor_names, stor_categories, stor_regionnames = readvector.(
            Ref(f["storages/_core"]), ["name", "category", "region"])

        stor_regions = getindex.(Ref(regionlookup), stor_regionnames)
        region_order = sortperm(stor_regions)

        storages = Storages{N,L,T,P,E}(
            stor_names[region_order], stor_categories[region_order],
            Int.(read(f["storages/chargecapacity"]))[region_order, :],
            Int.(read(f["storages/dischargecapacity"]))[region_order, :],
            Int.(read(f["storages/energycapacity"]))[region_order, :],
            read(f["storages/chargeefficiency"])[region_order, :],
            read(f["storages/dischargeefficiency"])[region_order, :],
            read(f["storages/carryoverefficiency"])[region_order, :],
            read(f["storages/failureprobability"])[region_order, :],
            read(f["storages/repairprobability"])[region_order, :]
        )

        region_stor_idxs = makeidxlist(stor_regions[region_order], n_regions)

    else

        storages = Storages{N,L,T,P,E}(
            String[], String[], 
            zeros(Int, 0, N), zeros(Int, 0, N), zeros(Int, 0, N),
            zeros(Float64, 0, N), zeros(Float64, 0, N), zeros(Float64, 0, N),
            zeros(Float64, 0, N), zeros(Float64, 0, N))

        region_stor_idxs = fill(1:0, n_regions)

    end


    if has_generatorstorages

        genstor_names, genstor_categories, genstor_regionnames = readvector.(
            Ref(f["generatorstorages/_core"]), ["name", "category", "region"])

        genstor_regions = getindex.(Ref(regionlookup), genstor_regionnames)
        region_order = sortperm(genstor_regions)

        generatorstorages = GeneratorStorages{N,L,T,P,E}(
            genstor_names[region_order], genstor_categories[region_order],
            Int.(read(f["generatorstorages/chargecapacity"]))[region_order, :],
            Int.(read(f["generatorstorages/dischargecapacity"]))[region_order, :],
            Int.(read(f["generatorstorages/energycapacity"]))[region_order, :],
            read(f["generatorstorages/chargeefficiency"])[region_order, :],
            read(f["generatorstorages/dischargeefficiency"])[region_order, :],
            read(f["generatorstorages/carryoverefficiency"])[region_order, :],
            Int.(read(f["generatorstorages/inflow"]))[region_order, :],
            Int.(read(f["generatorstorages/gridinjectioncapacity"]))[region_order, :],
            Int.(read(f["generatorstorages/gridwithdrawalcapacity"]))[region_order, :],
            read(f["generatorstorages/failureprobability"])[region_order, :],
            read(f["generatorstorages/repairprobability"])[region_order, :])

        region_genstor_idxs = makeidxlist(genstor_regions[region_order], n_regions)

    else

        generatorstorages = GeneratorStorages{N,L,T,P,E}(
            String[], String[], 
            zeros(Int, 0, N), zeros(Int, 0, N), zeros(Int, 0, N),
            zeros(Float64, 0, N), zeros(Float64, 0, N), zeros(Float64, 0, N),
            zeros(Int, 0, N), zeros(Int, 0, N), zeros(Int, 0, N),
            zeros(Float64, 0, N), zeros(Float64, 0, N))

        region_genstor_idxs = fill(1:0, n_regions)

    end

    if has_interfaces

        from_regions, to_regions =
            readvector.(Ref(f["interfaces/_core"]), ["region1", "region2"])

        interfaces = Interfaces{N,P}(
            getindex.(Ref(regionlookup), from_regions),
            getindex.(Ref(regionlookup), to_regions),
            Int.(read(f["interfaces/forwardcapacity"])),
            Int.(read(f["interfaces/backwardcapacity"])))

        n_interfaces = length(interfaces)
        interface_lookup = Dict((r1, r2) => i for (i, (r1, r2))
                                in enumerate(tuple.(from_regions, to_regions)))

        line_names, line_categories, line_fromregions, line_toregions =
            readvector.(Ref(f["lines/_core"]), ["name", "category", "region1", "region2"])

        line_interfaces = getindex.(Ref(interface_lookup), tuple.(line_fromregions, line_toregions))
        interface_order = sortperm(line_interfaces)

        lines = Lines{N,L,T,P}(
            line_names[interface_order], line_categories[interface_order],
            Int.(read(f["lines/forwardcapacity"]))[interface_order, :],
            Int.(read(f["lines/backwardcapacity"]))[interface_order, :],
            read(f["lines/failureprobability"])[interface_order, :],
            read(f["lines/repairprobability"])[interface_order, :])

        interface_line_idxs = makeidxlist(line_interfaces[interface_order], n_interfaces)

    else

        interfaces = Interfaces{N,P}(
            Int[], Int[], zeros(Int, 0, N), zeros(Int, 0, N))

        lines = Lines{N,L,T,P}(
            Int[], Int[], zeros(Int, 0, N), zeros(Int, 0, N),
            zeros(Float64, 0, N), zeros(Float64, 0, N))

        interface_line_idxs = UnitRange[]

    end

    return SystemModel(
        regions, interfaces,
        generators, region_gen_idxs,
        storages, region_stor_idxs,
        generatorstorages, region_genstor_idxs,
        lines, interface_line_idxs,
        timestamps)

end

"""
Attempts to parse the file's "vX.Y.Z" version label into (x::Int, y::Int, z::Int).
Errors if the label cannot be found or parsed as expected.
"""
function readversion(f::HDF5File)

    exists(attrs(f), "pras_dataversion") || error(
          "File format version indicator could not be found - the file may " *
          "not be a PRAS SystemModel representation.")

    versionstring = read(attrs(f)["pras_dataversion"])

    version = match(r"^v(\d+)\.(\d+)\.(\d+)$", versionstring)
    isnothing(version) && error("File format version $versionstring not recognized")

    major, minor, patch = parse.(Int, version.captures)

    return (major, minor, patch), versionstring

end

"""
Attempts to extract a vector of elements from an HDF5 compound datatype,
corresponding to `field`.
"""
function readvector(d::HDF5Dataset, field::String)
    data = read(d)
    fieldorder = data[1].membername
    idx = findfirst(isequal(field), fieldorder)
    fieldtype = data[1].membertype[idx]
    return fieldtype.(getindex.(getfield.(data, :data), idx))
end
