// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "../pasta/Fields.sol";
import "./Sponge.sol";

contract PoseidonPermutation {
    using {Pasta.add, Pasta.mul, Pasta.pow} for Pasta.Fp;
    function sbox(Pasta.Fp f) internal view returns (Pasta.Fp) {
        return f.pow(7);
    }

    function apply_mds(
        PoseidonSponge.Sponge memory sponge
    ) internal pure returns (Pasta.Fp[3] memory n) {
        n[0] = sponge.state[0].mul(mds0).add(sponge.state[1].mul(mds1)).add(sponge.state[2].mul(mds2));
        n[1] = sponge.state[0].mul(mds3).add(sponge.state[1].mul(mds4)).add(sponge.state[2].mul(mds5));
        n[2] = sponge.state[0].mul(mds6).add(sponge.state[1].mul(mds7)).add(sponge.state[2].mul(mds8));
    }

    function apply_round(
        uint256 round,
        PoseidonSponge.Sponge memory sponge
    ) internal view {
        sponge.state[0] = sbox(sponge.state[0]);
        sponge.state[1] = sbox(sponge.state[1]);
        sponge.state[2] = sbox(sponge.state[2]);

        sponge.state = apply_mds(sponge);

        //sponge.state[0] = sponge.state[0].add(round_constant);
    }

    Pasta.Fp internal constant mds0 = Pasta.Fp.wrap(12035446894107573964500871153637039653510326950134440362813193268448863222019);
    Pasta.Fp internal constant mds1 = Pasta.Fp.wrap(25461374787957152039031444204194007219326765802730624564074257060397341542093);
    Pasta.Fp internal constant mds2 = Pasta.Fp.wrap(27667907157110496066452777015908813333407980290333709698851344970789663080149);
    Pasta.Fp internal constant mds3 = Pasta.Fp.wrap(4491931056866994439025447213644536587424785196363427220456343191847333476930);
    Pasta.Fp internal constant mds4 = Pasta.Fp.wrap(14743631939509747387607291926699970421064627808101543132147270746750887019919);
    Pasta.Fp internal constant mds5 = Pasta.Fp.wrap(9448400033389617131295304336481030167723486090288313334230651810071857784477);
    Pasta.Fp internal constant mds6 = Pasta.Fp.wrap(10525578725509990281643336361904863911009900817790387635342941550657754064843);
    Pasta.Fp internal constant mds7 = Pasta.Fp.wrap(27437632000253211280915908546961303399777448677029255413769125486614773776695);
    Pasta.Fp internal constant mds8 = Pasta.Fp.wrap(27566319851776897085443681456689352477426926500749993803132851225169606086988);


}
