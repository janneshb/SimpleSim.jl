@testset "Test Utils" begin
    @testset "Check Rational" begin
        _x = 1 // 10
        x = SimpleSim.check_rational(_x)
        @test typeof(x) <: Rational

        _x = 2
        x = SimpleSim.check_rational(_x)
        @test typeof(x) <: Rational

        _x = 3.0
        x = SimpleSim.check_rational(_x)
        @test typeof(x) <: Rational

        _x = 4u"s"
        x = SimpleSim.check_rational(_x)
        @test typeof(x) <: Quantity{<:Rational}

        # Float Unitful variables currently cannot be rationalized
        #_x = 5.0u"m"
        #x = SimpleSim.check_rational(_x)
        #@test typeof(x) <: Quantity{<:Rational}

        g = gcd((20 // 1)u"s", (24 // 1)u"s")
        @test typeof(g) <: Quantity{<:Rational}
        @test g.val == 4 // 1
    end
end
