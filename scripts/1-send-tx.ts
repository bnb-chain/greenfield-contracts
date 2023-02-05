import {ethers} from "hardhat";
import { GnfdLightClient } from "../typechain-types";


const main = async () => {
    const lc = (await ethers.getContractAt('GnfdLightClient', "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6")) as GnfdLightClient


    const payload = "0x00010002010000000000000003000000000063ddf59300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000eb7b9476d244ce05c3de4bbc6fdd7f56379b145709ade9941ac642f1329404e04850e1dee5e0abe903e62211";
    const sig =
        "0xb352e9b52ae49bc6ffaf7e975dd7d924ece56b709c88869e22bc832852bf7e033a420f6ca73b74403c46df9f601e323b194602e2ac1fa293f3badf3a306451afa4d071314b73428e99a4da5e444147fe001cb7c7b3d3603a521cbf340e6b1128";
    const bitMap = 7;

    const tx = await lc.verifyPackage(payload, sig, bitMap, {
        gasLimit: 500_0000
    })

    console.log(tx)
    // const receipt = await tx.wait(1)
    // console.log(receipt)

}

main().then()
