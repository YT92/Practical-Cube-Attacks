#include<Windows.h>
#include "trivium.h"
#include "ecrypt-sync.h"
#include <stdio.h>
#include<time.h>
#include<math.h>
#include<windows.h>

void choose_random_key(u32 KEY[]);
void tocnf(int VN, const char* stropenpath);
void solve(int searnum,char searpath[],int equnum);
u32 getsolnum(u8  sol[][80]);
void genrandomkey(u32 randomkey[][10],u32 twokeysum[][10]);
void genrandomkeyV2(u32 randomkey[][10],u32 twokeysum[][10]);
void genrandomkeyV3(u32 randomkey[][10],u32 twokeysum[][10]);
void genrandomkey_qua(u32 randomkey[][10],u32 twokeysum[][10]);
void genrandomkeyV2Right(u32 randomkey[][10],u32 twokeysum[][10]);
void GenRandomKeyV3Right(u32 randomkey[][10],u32 twokeysum[][10]);