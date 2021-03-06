using GeoData, Test

A = [missing 7; 2 missing]
ga = GeoArray(A, (X, Y); missingval=missing)
ga99 = replace_missing(ga, -9999)

@testset "boolmask" begin
    @test boolmask(A) == [false true; true false]
    @test boolmask(ga) == [false true; true false]
    @test boolmask(ga99) == [false true; true false]
    @test dims(boolmask(ga)) == (X(Base.OneTo(2), mode=NoIndex()), Y(Base.OneTo(2), mode=NoIndex()))
end

@testset "missingmask" begin
    @test all(missingmask(A) .=== [missing true; true missing])
    @test all(missingmask(ga) .=== [missing true; true missing])
    @test all(missingmask(ga99) .=== [missing true; true missing])
    @test dims(missingmask(ga)) == (X(Base.OneTo(2), mode=NoIndex()), Y(Base.OneTo(2), mode=NoIndex()))
end
