//******************************************************************//
//In this algorithm, based on the division property with the flag t-//
//echnique, we estimate the upper bound of the degree of the superp-//
//oly of a given cube under specific conditions impose on key/iv va-//
//riables.                                                          //
//Althogh the division property with flag technique is not accurate,//
//it is secure to use it to estimate the upper bound of the degree //
//of a superpoly of a cube.                                        //
//****************************NOTE**********************************//
//1. The code is writen in C# and the MILP solver used is Gurobi 7.5//
//   To run it, we should use release/x64 mode and cite the         //
//   Gurobi75Net.dll.                                               //
//******************************************************************//


using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Gurobi;
using System.IO;
namespace gorubi
{
    class Program
    {
        static void Main(string[] args)
        {

            //int round = 799-160;
            int round = 810 - 200;
            int termnum = 120;
            List<int> deglist = new List<int>();
            //StreamWriter MaxDegT = new StreamWriter("MaxdegreeTerms.txt");
            //int startround = 799;
            // List<uint> seedcube = new List<uint>() { 0,4,6,9,13,20,24,32,37,42,46,48,53,57,76,11,79,17,7,16,2,22,40,5,26,31,68,15,28,51,30,38,44,3,71,34,58,63,66,61,73,1,12,62,55,18,8,14,33,19,10,36,39,21,60,23 };//62, 68, 70, 73, 76, 78
            //List<uint> curcube = new List<uint>() { 0,4,6,9,13,20,24,32,37,42,46,48,53,57,76,11,79,17,7,16,2,22,40,5,26,31,68,15,28,51,30,38,44,3,71,34,58,63,66,61,73,1,12,62,55,18,8,14,33,19,10,36,39,21,60,23 };
            //List<uint> seedcube = new List<uint>() {11,13,15,18,22,26,30,36,38,43,49,51,52,55,57,62,65,66,2,6,4,8,70,79,28,25,34,0,21,16,9,47,32,27,23};
            //List<uint> curcube = new List<uint>() {11,13,15,18,22,26,30,36,38,43,49,51,52,55,57,62,65,66,2,6,4,8,70,79,28,25,34,0,21,16,9,47,32,27,23};
            //List<uint> seedcube = new List<uint>(){4,6,10,11,25,17,19,21,25,29,32,34,36,39,41,43,50,2,70,0,15,8,27,26,79,1,13,28,45,38,23,9,47,76,67,24};
            //List<uint> curcube= new List<uint>(){4,6,10,11,25,17,19,21,25,29,32,34,36,39,41,43,50,2,70,0,15,8,27,26,79,1,13,28,45,38,23,9,47,76,67,24};
            //List<uint> seedcube = new List<uint>(){0,2,6,7,9,11,13,15,18,20,22,24,35,37,39,42,4,78,25,26,17,27,28,45,33,50,10,48,61,76,30,63,16,12,67,8};
            //List<uint> curcube = new List<uint>(){0,2,6,7,9,11,13,15,18,20,22,24,35,37,39,42,4,78,25,26,17,27,28,45,33,50,10,48,61,76,30,63,16,12,67,8};
            //round 810
            //List<uint> seedcube =new List<uint>{2,6,8,10,11,15,19,21,25,29,30,32,34,36,39,41,43,45,50,0,75,12,4,14,20,22,16,27,23,72,52,55,60,37,79,62,64,47,54,69,51};
            //List<uint> curcube = new List<uint>(){2,6,8,10,11,15,19,21,25,29,30,32,34,36,39,41,43,45,50,0,75,12,4,14,20,22,16,27,23,72,52,55,60,37,79,62,64,47,54,69,51};
            //List<uint> seedcube =new List<uint>{5,7,9,11,13,16,18,20,26,28,30,31,33,37,40,44,46,21,75,0,2,4,22,23,1,32,3,35,36,39,56,63,78,42,51,71,49,73,34,29,65,6,19,48};
            // List<uint> curcube =new List<uint>{5,7,9,11,13,16,18,20,26,28,30,31,33,37,40,44,46,21,75,0,2,4,22,23,1,32,3,35,36,39,56,63,78,42,51,71,49,73,34,29,65,6,19,48};
            //List<uint> seedcube= new List<uint>(){0,2,6,7,9,11,13,15,18,20,22,24,35,37,39,42,4,78,25,26,17,27,28,45,33,50,10,48,61,76,30,63,16,12,67,8};
            //List<uint> curcube= new List<uint>(){0,2,6,7,9,11,13,15,18,20,22,24,35,37,39,42,4,78,25,26,17,27,28,45,33,50,10,48,61,76,30,63,16,12,67,8};
            //List<uint> seedcube= new List<uint>(){0,2,4,13,15,17,20,22,29,32,34,38,41,44,48,58,60,71,6,27,69,8,19,9,36,10,11,25,62,79,77,46,21,66,51,1,24};
            //List<uint> curcube= new List<uint>(){0,2,4,13,15,17,20,22,29,32,34,38,41,44,48,58,60,71,6,27,69,8,19,9,36,10,11,25,62,79,77,46,21,66,51,1,24};
            //List<uint> seedcube= new List<uint>(){2,5,7,10,15,17,26,32,33,35,50,55,56,59,61,63,66,79,19,0,11,27,1,25,28,37,13,9,22,24,30,48,43,76,39,44,46,52,8};
            // List<uint> curcube= new List<uint>(){2,5,7,10,15,17,26,32,33,35,50,55,56,59,61,63,66,79,19,0,11,27,1,25,28,37,13,9,22,24,30,48,43,76,39,44,46,52,8};
            // List<uint> seedcube= new List<uint>(){4,6,10,11,15,17,19,21,25,29,32,34,36,39,41,43,50,2,69,79,8,27,0,1,28,71,13,45,23,26,38,76,47,52,48,42};
            // List<uint> curcube= new List<uint>(){4,6,10,11,15,17,19,21,25,29,32,34,36,39,41,43,50,2,69,79,8,27,0,1,28,71,13,45,23,26,38,76,47,52,48,42};
            //List<uint> seedcube= new List<uint>(){2,6,8,10,11,15,19,21,25,29,30,32,34,36,39,41,43,45,50,0,75,12,4,14,20,22,16,27,23,72,52,55,60,37,79,62,64,47,54,69,51,71,18,53};
            //List<uint> curcube= new List<uint>(){2,6,8,10,11,15,19,21,25,29,30,32,34,36,39,41,43,45,50,0,75,12,4,14,20,22,16,27,23,72,52,55,60,37,79,62,64,47,54,69,51,71,18,53};
            //List<uint> seedcube = new List<uint>() { 4, 6, 10, 11, 15, 17, 19, 21, 25, 29, 32, 34, 36, 39, 41, 43, 50, 2, 69, 79, 8, 27, 0, 1, 28, 71, 13, 45, 23, 26, 38, 76, 47, 52, 57, 42 };//805-12
            //List<uint> curcube = new List<uint>() { 4, 6, 10, 11, 15, 17, 19, 21, 25, 29, 32, 34, 36, 39, 41, 43, 50, 2, 69, 79, 8, 27, 0, 1, 28, 71, 13, 45, 23, 26, 38, 76, 47, 52, 57, 42 };//805-12
            List<uint> seedcube = new List<uint>() { 2,3,6,8,10,12,17,19,23,30,32,34,36,39,41,75,0,14,15,4,20,5,73,21,56,71,22,7,43,24,27,65,58,45,37,47,52,69,60,35,38,66};//805-12
            List<uint> curcube = new List<uint>() { 2,3,6,8,10,12,17,19,23,30,32,34,36,39,41,75,0,14,15,4,20,5,73,21,56,71,22,7,43,24,27,65,58,45,37,47,52,69,60,35,38,66};//805-12


            List<uint> remcube = new List<uint>() { };
            int deg = 100;
            int k = 0;
            int m = 0;
            int mini = 1000;
            int miniloc = 0;
            int maxdeg = -1;
            int curdeg = 30;
            // int mindeg = 1000;
            for (uint i = 0; i < 80; i++)
            {
                if (!curcube.Contains(i))
                {
                    remcube.Add(i);
                }
            }
            //the target round runs from 960 to 1152.
            //for (round = startround; round < 785; round++)
            while (mini > 3)
            {
                //需要更新remcube
                remcube.Clear();
                for (uint i = 0; i < 80; i++)
                {
                    if (!curcube.Contains(i))
                    {
                        remcube.Add(i);
                    }
                }
                for (k = 0; k < curcube.Count; k++)
                {
                    Console.Write(curcube[k] + " ");
                }
                Console.WriteLine();
                for (k = 0; k < remcube.Count; k++)
                {
                    Console.Write(remcube[k] + " ");
                }
                mini = 100;
                for (k = 0; k < remcube.Count; k++)
                {
                    //for(m=0;m<55)
                    StreamReader terms = new StreamReader("terms.txt");
                    Console.Write("\n****************** The " + round.ToString() + "-th round ******************\n");
                    for (int i = 0; i < curcube.Count; i++)
                        Console.Write(curcube[i] + " ");
                    Console.Write(remcube[k] + " ");
                    Console.WriteLine();
                    maxdeg = -1;
                    int NO = 0;
                    curdeg = 0;
                    for (m = 0; m < termnum; m++)
                    {
                        string strtmp = terms.ReadLine();
                        string[] mon = strtmp.Split(',');
                        int[] pos = new int[mon.Length];
                        for (int i = 0; i < mon.Length; i++)
                        {
                            pos[i] = Convert.ToInt32(mon[i]);
                        }
                        GRBEnv env = new GRBEnv("Trvium.log");
                        GRBModel model = new GRBModel(env);

                        //设置gurobi不输出中间结果
                        model.Parameters.LogToConsole = 0;
                        //int[] pos = new int[] { 54,78,79 };//6个输出位置 65,92, 161, 176, 242, 287
                        //int[] pos = new int[3] {  };//6个输出位置
                        GRBVar[] IV = model.AddVars(80, GRB.BINARY);
                        GRBVar[] Key = model.AddVars(80, GRB.BINARY);
                        for (int i = 0; i < 80; i++)
                        {
                            IV[i].VarName = "IV" + i.ToString();//IV变量,命名为IV0-IV79
                            Key[i].VarName = "Key" + i.ToString();//IV变量,命名为Key0-Key79
                        }
                        GRBVar[] s = model.AddVars(288, GRB.BINARY);

                        for (int i = 0; i < 288; i++)
                            s[i].VarName = "var" + i.ToString();//288个寄存器,命名为var0-var288
                        char[] FlagS = new char[288];//288个寄存器的Flag

                        GRBVar[] NewVars = model.AddVars(30 * round, GRB.BINARY);
                        for (int i = 0; i < NewVars.Length; i++)
                            NewVars[i].VarName = "y" + i.ToString();//每过一次更新许需要加30个变量，总共为30*round,命名为y0-y300*round
                        char[] FlagNewVars = new char[30 * round];//新加变量的Flag



                        List<uint> cube = new List<uint>() { };//62, 68, 70, 73, 76, 78

                        for (int i = 0; i < curcube.Count; i++)
                        {
                            cube.Add(curcube[i]);
                        }
                        //每次增加一个

                        cube.Add(remcube[k]);

                        List<uint> ivbits_set_to_1 = new List<uint>() { };//设置成1的iv比特
                        List<uint> ivbits_set_to_0 = new List<uint>() { };//设置成0的iv比特
                        for (uint i = 0; i < 80; i = i + 1)
                            ivbits_set_to_0.Add(i);
                        for (int i = 0; i < cube.Count; i++)
                        {
                            ivbits_set_to_0.Remove(cube[i]);
                        }
                        //  for (int i = 0; i < cube.Count; i++)
                        //Console.Write(cube[i] + " ");
                        //Console.WriteLine();

                        List<UInt32> Noncube = new List<uint>() { 0x0, 0x0, 0x0 };//Noncube stores the value of the non-cube variables

                        //for each iv bit which is set to 1, set the corresponding bit of Noncube to 1.
                        for (int i = 0; i < ivbits_set_to_1.Count; i++)
                        {
                            Noncube[(int)ivbits_set_to_1[i] >> 5] |= (uint)(0x01 << ((int)(ivbits_set_to_1[i] & 0x1f)));
                        }

                        GRBLinExpr ChooseIV = new GRBLinExpr();//
                        for (int i = 0; i < cube.Count; i++)
                            ChooseIV.AddTerm(1.0, IV[cube[i]]);

                        //the bits set to constants
                        List<int> chokey = new List<int>() { };

                        //pick up the key variables which are not fixed.
                        //i.e. keydeg= k_i1+k_i2+...+k_in, where k_i1,k_i2,...,k_im are the key bits which are not fixed
                        GRBLinExpr keydeg = new GRBLinExpr();
                        for (int i = 0; i < 80; i++)
                        {
                            if (!chokey.Contains(i))
                                keydeg.AddTerm(1.0, Key[i]);
                        }
                        if (curdeg != 0)
                            model.AddConstr(keydeg >= curdeg + 1, "New");
                        //set maximizing the linear expression keydeg as the objective function of our model
                        //Hence, we could obtain the upper bound of the degree of the superpoly of the chosen cube.
                        //model.AddConstr(keydeg <= mini, "ConsOnMaxDeg");
                        model.SetObjective(keydeg, GRB.MAXIMIZE);

                        //in this function, we set the conditions which are imposed to the key bits and iv bits
                        //before running, it needs to set some parameters, such as the key bits set to 0/1 and so on, in this function,
                        initial(model, s, FlagS, cube, Noncube, IV, Key);

                        int VarNumber = 0;

                        //describe the propagation of the division property with flag through Trivium
                        for (int i = 1; i <= round; i++)
                            Triviumcore(model, s, FlagS, NewVars, FlagNewVars, ref VarNumber);

                        for (int i = 0; i < 288; i++)
                        {
                            if (!pos.Contains(i))
                            {
                                model.AddConstr(s[i] == 0, "a" + i.ToString());
                            }
                        }
                        GRBLinExpr expr = new GRBLinExpr();
                        //for (int i = 0; i < pos.Count(); i++)
                        //expr.AddTerm(1.0, s[pos[i]]);
                        //model.AddConstr(expr == 1, "t1");
                        for (int i = 0; i < 288; i++)
                        {
                            if (pos.Contains(i))
                            {
                                model.AddConstr(s[i] == 1, "1");
                            }
                            else
                            {
                                model.AddConstr(s[i] == 0, "1");
                            }
                        }
                        //solve the MILP model.
                        model.Optimize();
                        int currentdeg = 0;

                        //outout the solution

                        // is the model is feasible the upper bound of the degree of the superpoly is large than 0.
                        // In this case, we output a possible term of degree d, where d is the upper bound of the degree of the superpoly.
                        if (model.SolCount > 0)
                        {
                            //StreamWriter MaxDegT = new StreamWriter("MaxdegreeTerms.txt", true);
                            currentdeg = (int)model.ObjVal;
                            NO++;
                            Console.WriteLine("****************No." + m + "********************");
                            for (int ii = 0; ii < pos.Length; ii++)
                            {
                                Console.Write(pos[ii] + ",");
                            }
                            Console.WriteLine(" " + currentdeg);
                            //MaxDegT.WriteLine("****************No." + NO + "********************\n");
                            if (currentdeg >= maxdeg)
                            {
                                maxdeg = currentdeg;
                            }
                            curdeg = maxdeg;
                        }
                        else//if the model is imfeasible, then the degree of the superpoly is upper bounded by 0.
                        {
                            currentdeg = 0;
                            Console.WriteLine("****************No." + m + "********************");
                            if (currentdeg >= maxdeg)
                            {
                                maxdeg = currentdeg;
                            }
                        }
                        model.Dispose();
                        env.Dispose();
                        //如果是maxdeg>mini了, 就可以跳出循环了
                        if (currentdeg >= 4)
                        {
                            break;
                        }
                    }
                    //输出最大次项
                    StreamWriter MaxDegT = new StreamWriter("MaxdegreeTerms.txt", true);
                    MaxDegT.WriteLine("*****************round" + round + "**********************\n");
                    for (int i = 0; i < curcube.Count; i++)
                    {
                        MaxDegT.Write(curcube[i] + ",");
                    }
                    MaxDegT.Write(remcube[k]);
                    MaxDegT.WriteLine();
                    MaxDegT.Write("Upper bound of degree of superpoly: ");
                    Console.WriteLine(maxdeg);
                    MaxDegT.WriteLine(maxdeg);
                    MaxDegT.Write("\n\n***********************************************\n");
                    Console.Write("\n***********************************************\n");
                    Console.WriteLine();
                    MaxDegT.WriteLine();
                    MaxDegT.Close();
                    //if (mini < maxdeg)
                    if (maxdeg < mini)
                    {
                        mini = maxdeg;
                        miniloc = k;
                    }
                    terms.Close();
                }
                curcube.Add(remcube[miniloc]);
            }
            Console.ReadLine();

        }

        //initialize the model and set the conditions imposed to the key/iv bits.
        static void initial(GRBModel model, GRBVar[] s, char[] FlagS, List<uint> cube, List<UInt32> Noncube, GRBVar[] IV, GRBVar[] Key)
        {
            //key bits set to 0
            List<int> chosenkey = new List<int>() { };
            //key bits set to 1
            List<int> onekey = new List<int>() { };
            for (int i = 0; i < 80; i++)
            {
                //set key bits in chosenkey to constant 0
                if (chosenkey.Contains(i))
                {
                    model.AddConstr(s[i] == 0, "z" + i.ToString());
                    FlagS[i] = '0';
                }
                else
                {
                    //set the key bits in onekey to constant 1
                    if (onekey.Contains(i))
                    {
                        Console.WriteLine("******" + i + "********");
                        model.AddConstr(s[i] == 0, "z" + i.ToString());
                        FlagS[i] = '1';
                    }
                    else// treat the remaining key bits as variables.
                    {
                        model.AddConstr(s[i] == Key[i], "z" + i.ToString());
                        FlagS[i] = '2';
                    }
                }
            }

            for (int i = 80; i < 93; i++)
            {
                model.AddConstr(s[i] == 0, "z" + i.ToString());
                FlagS[i] = '0';
            }


            if (Noncube.Count == 0)//if the noncube variables are not set to constants
            {
                for (uint i = 93; i < 173; i++)
                {

                    if (cube.Contains(i - 93))
                    {
                        model.AddConstr(s[i] == 1, "IV" + i.ToString());
                    }
                    else
                    {
                        model.AddConstr(s[i] == 0, "z" + i.ToString());
                    }
                    FlagS[i] = '2';
                }
            }
            else//if the non-cube variables are set to constants
            {
                for (uint i = 93; i < 173; i++)
                {
                    //treat the iv bits in cube as variable
                    if (cube.Contains(i - 93))
                    {
                        model.AddConstr(s[i] == 1, "z" + i.ToString());
                        FlagS[i] = '2';
                    }
                    else
                    {
                        //model.AddConstr(IV[i - 93] == 0, "IV" + i.ToString());
                        model.AddConstr(s[i] == 0, "z" + i.ToString());
                        int pos1 = (int)((i - 93) >> 5);
                        int pos2 = (int)(((i - 93) & 0x1f));
                        //the flag of iv bits which are set to 1 is set to '1'
                        if (((Noncube[pos1] >> pos2) & 0x01) == 1)
                        {
                            FlagS[i] = '1';
                        }
                        else //the flag of iv bits which are set to 0 is set to '0'
                        {
                            FlagS[i] = '0';
                        }
                    }
                }
            }
            //initialize the state bits which are loaded with constants
            //namely, set the last 4 bits of the second register and the first 108 bits in the third register to constant 0
            //set the last 3 bits of the third register to 1.
            for (int i = 173; i < 285; i++)
            {
                model.AddConstr(s[i] == 0, "z" + i.ToString());
                FlagS[i] = '0';
            }
            for (int i = 285; i < 288; i++)
            {
                model.AddConstr(s[i] == 0, "z" + i.ToString());
                FlagS[i] = '1';
            }


        }

        //describe the propagation of division property through the round function of Trivium
        static void Triviumcore(GRBModel model, GRBVar[] s, Char[] FlagS, GRBVar[] NewVar, char[] FlagNewVar, ref int VarNumber)
        {

            int[] posA = new int[5] { 65, 170, 90, 91, 92 };
            for (int i = 0; i < 4; i++)
            {
                model.AddConstr(NewVar[VarNumber + 2 * i] + NewVar[VarNumber + 2 * i + 1] == s[posA[i]], "c" + (VarNumber + i).ToString());
                FlagNewVar[VarNumber + 2 * i] = FlagS[posA[i]];
                FlagNewVar[VarNumber + 2 * i + 1] = FlagS[posA[i]];
            }
            model.AddConstr(NewVar[VarNumber + 8] >= NewVar[VarNumber + 5], "c" + (VarNumber + 5).ToString());
            model.AddConstr(NewVar[VarNumber + 8] >= NewVar[VarNumber + 7], "c" + (VarNumber + 6).ToString());
            FlagNewVar[VarNumber + 8] = FlagMul(FlagNewVar[VarNumber + 5], FlagNewVar[VarNumber + 7]);
            if (FlagNewVar[VarNumber + 8] == '0')
                model.AddConstr(NewVar[VarNumber + 8] == 0, "t" + (VarNumber / 10).ToString());
            model.AddConstr(NewVar[VarNumber + 9] == s[posA[4]] + NewVar[VarNumber + 8] + NewVar[VarNumber + 1] + NewVar[VarNumber + 3], "c" + (VarNumber + 7).ToString());
            FlagNewVar[VarNumber + 9] = FlagAdd(FlagAdd(FlagS[posA[4]], FlagNewVar[VarNumber + 8]), FlagAdd(FlagNewVar[VarNumber + 1], FlagNewVar[VarNumber + 3]));
            VarNumber = VarNumber + 10;

            int[] posB = new int[5] { 161, 263, 174, 175, 176 };
            for (int i = 0; i < 4; i++)
            {
                model.AddConstr(NewVar[VarNumber + 2 * i] + NewVar[VarNumber + 2 * i + 1] == s[posB[i]], "c" + (VarNumber + i).ToString());
                FlagNewVar[VarNumber + 2 * i] = FlagS[posB[i]];
                FlagNewVar[VarNumber + 2 * i + 1] = FlagS[posB[i]];
            }
            model.AddConstr(NewVar[VarNumber + 8] >= NewVar[VarNumber + 5], "c" + (VarNumber + 5).ToString());
            model.AddConstr(NewVar[VarNumber + 8] >= NewVar[VarNumber + 7], "c" + (VarNumber + 6).ToString());
            FlagNewVar[VarNumber + 8] = FlagMul(FlagNewVar[VarNumber + 5], FlagNewVar[VarNumber + 7]);
            if (FlagNewVar[VarNumber + 8] == '0')
                model.AddConstr(NewVar[VarNumber + 8] == 0, "t" + (VarNumber / 10).ToString());
            model.AddConstr(NewVar[VarNumber + 9] == s[posB[4]] + NewVar[VarNumber + 8] + NewVar[VarNumber + 1] + NewVar[VarNumber + 3], "c" + (VarNumber + 7).ToString());
            FlagNewVar[VarNumber + 9] = FlagAdd(FlagAdd(FlagS[posB[4]], FlagNewVar[VarNumber + 8]), FlagAdd(FlagNewVar[VarNumber + 1], FlagNewVar[VarNumber + 3]));
            VarNumber = VarNumber + 10;

            int[] posC = new int[5] { 242, 68, 285, 286, 287 };
            for (int i = 0; i < 4; i++)
            {
                model.AddConstr(NewVar[VarNumber + 2 * i] + NewVar[VarNumber + 2 * i + 1] == s[posC[i]], "c" + (VarNumber + i).ToString());
                FlagNewVar[VarNumber + 2 * i] = FlagS[posC[i]];
                FlagNewVar[VarNumber + 2 * i + 1] = FlagS[posC[i]];
            }
            model.AddConstr(NewVar[VarNumber + 8] >= NewVar[VarNumber + 5], "c" + (VarNumber + 5).ToString());
            model.AddConstr(NewVar[VarNumber + 8] >= NewVar[VarNumber + 7], "c" + (VarNumber + 6).ToString());
            FlagNewVar[VarNumber + 8] = FlagMul(FlagNewVar[VarNumber + 5], FlagNewVar[VarNumber + 7]);
            if (FlagNewVar[VarNumber + 8] == '0')
                model.AddConstr(NewVar[VarNumber + 8] == 0, "t" + (VarNumber / 10).ToString());
            model.AddConstr(NewVar[VarNumber + 9] == s[posC[4]] + NewVar[VarNumber + 8] + NewVar[VarNumber + 1] + NewVar[VarNumber + 3], "c" + (VarNumber + 7).ToString());
            FlagNewVar[VarNumber + 9] = FlagAdd(FlagAdd(FlagS[posC[4]], FlagNewVar[VarNumber + 8]), FlagAdd(FlagNewVar[VarNumber + 1], FlagNewVar[VarNumber + 3]));
            VarNumber = VarNumber + 10;

            for (int i = 287; i > 0; i--)
            {
                s[i] = s[i - 1];
                FlagS[i] = FlagS[i - 1];
            }
            s[0] = NewVar[VarNumber - 10 + 9]; FlagS[0] = FlagNewVar[VarNumber - 10 + 9];
            s[287] = NewVar[VarNumber - 10 + 6]; FlagS[287] = FlagNewVar[VarNumber - 10 + 6];
            s[286] = NewVar[VarNumber - 10 + 4]; FlagS[286] = FlagNewVar[VarNumber - 10 + 4];
            s[69] = NewVar[VarNumber - 10 + 2]; FlagS[69] = FlagNewVar[VarNumber - 10 + 2];
            s[243] = NewVar[VarNumber - 10 + 0]; FlagS[243] = FlagNewVar[VarNumber - 10 + 0];
            s[177] = NewVar[VarNumber - 20 + 9]; FlagS[177] = FlagNewVar[VarNumber - 20 + 9];
            s[176] = NewVar[VarNumber - 20 + 6]; FlagS[176] = FlagNewVar[VarNumber - 20 + 6];
            s[175] = NewVar[VarNumber - 20 + 4]; FlagS[175] = FlagNewVar[VarNumber - 20 + 4];
            s[264] = NewVar[VarNumber - 20 + 2]; FlagS[264] = FlagNewVar[VarNumber - 20 + 2];
            s[162] = NewVar[VarNumber - 20 + 0]; FlagS[162] = FlagNewVar[VarNumber - 20 + 0];
            s[93] = NewVar[VarNumber - 30 + 9]; FlagS[93] = FlagNewVar[VarNumber - 30 + 9];
            s[92] = NewVar[VarNumber - 30 + 6]; FlagS[92] = FlagNewVar[VarNumber - 30 + 6];
            s[91] = NewVar[VarNumber - 30 + 4]; FlagS[91] = FlagNewVar[VarNumber - 30 + 4];
            s[171] = NewVar[VarNumber - 30 + 2]; FlagS[171] = FlagNewVar[VarNumber - 30 + 2];
            s[66] = NewVar[VarNumber - 30 + 0]; FlagS[66] = FlagNewVar[VarNumber - 30 + 0];
        }

        //propagation rule on the XOR operation  of flag 
        static char FlagAdd(char FlagA, char FlagB)
        {
            if (FlagA == '0')
            {
                return FlagB;
            }
            else if (FlagA == '1')
            {
                if (FlagB == '0')
                    return FlagA;
                else if (FlagB == '1')
                    return '0';
                else
                    return '2';
            }
            else
            {
                return '2';
            }

        }
        //propagation rule on the AND operation of flag 
        static char FlagMul(char FlagA, char FlagB)
        {
            if (FlagA == '0')
            {
                return '0';
            }
            else if (FlagA == '1')
            {
                return FlagB;
            }
            else
            {
                if (FlagB == '0')
                    return '0';
                else
                    return FlagA;
            }
        }
    }
}
