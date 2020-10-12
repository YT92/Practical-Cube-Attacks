//首先是结构体,u32,之后只需要将声明改过来就好了
#include<Windows.h>
#include "trivium.h"
#include "ecrypt-sync.h"
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
//#include"cube attack.h"
#include <stdio.h>
#include<time.h>
#include<math.h>
#include"randomkey.h"
#define imin(a,b) (a<b?a:b)
#define TYPE unsigned int
//__constant__ u32 iv[10];
const int threadsPerBlock=1024;
//const int threadsPerBlock=32;
u8 firstoutput=1;
//__constant__ ECRYPT_ctx ctx;
//选择随机密钥,在host端函数调用,然后将生成的随机密钥送入到
void choose_random_key(u32 KEY[])
{
	u8 i=0;
	u8 j=0;

	KEY[0]=rand()&0x000000FF;
 for(i=1;i<10;i++)
   {
	KEY[i]=rand()&0x000000FF;
LOOP: for (j=0;j<i;j++)
	  {
		if (KEY[i]==KEY[j]) 
		{
         KEY[i]=rand()&0x000000FF;
		 goto LOOP;
		}
	  }
   }
}

//void Moebius(TYPE *Tab, TYPE size)
void Moebius(TYPE *Tab, unsigned __int64 size)
{
	unsigned __int64  Wsize;
	//TYPE i,i0,i1; 
	//TYPE step;
	TYPE temp;
	unsigned __int64 i,i0,i1;
	unsigned __int64 step;
	Wsize=size/(8*sizeof(TYPE));
	
	/*Moebius transform for high order bits, using word ops*/
	for (step=1;step<Wsize;step<<=1) {
		for (i1=0;i1<Wsize;i1+=2*step) {
			for (i0=0;i0<step;i0++) {
				i=i1+i0;
				Tab[i+step]^=Tab[i];
			}
		}
	}
	
/*Moebius transform for low order bits, within words*/
/* Assumes 8*sizeof(TYPE)=32 */
	for(i=0;i<Wsize;i++) {
		TYPE tmp;
		tmp=Tab[i];
		tmp^=(tmp<<16);
		tmp^=(tmp&0xff00ff)<<8;
		tmp^=(tmp&0xf0f0f0f)<<4;
		tmp^=(tmp&0x33333333)<<2;
		tmp^=(tmp&0x55555555)<<1;
		Tab[i]=tmp;
	}
}
__device__ u32 reverse_word(u32 a)
{
	u32 b = 0;

	b = ((a&0x000000FF)<<24)^((a&0x0000FF00)<<8)^((a&0x00FF0000)>>8)^((a&0xFF000000)>>24);
	b = ((b&0x01010101)<<7)^((b&0x02020202)<<5)^((b&0x04040404)<<3)^((b&0x08080808)<<1)^((b&0x10101010)>>1)^((b&0x20202020)>>3)^((b&0x40404040)>>5)^((b&0x80808080)>>7);

	return(b);
}

 __device__ u32 Trivium_update_funcion_word(ECRYPT_ctx* ctx)
{
	u32 t1,t2,t3;
	u32 s66,s93,s162,s177,s243,s288,s91,s92,s171,s175,s176,s264,s286,s287,s69;
	u32 z;

	s66 = (ctx->s[2]<<30)|(ctx->s[1]>>2);//相或之后相当于直接级联
	s93 = (ctx->s[2]<<3)|(ctx->s[1]>>29);
	s162 = (ctx->s[5]<<27)|(ctx->s[4]>>5);
	s177 = (ctx->s[5]<<12)|(ctx->s[4]>>20);
	s243 = (ctx->s[8]<<30)|(ctx->s[7]>>2);
	s288 = (ctx->s[9]<<17)| (ctx->s[8]>>15);

	t1 = s66^s93;

	t2 = s162^s177;

	t3 = s243^s288;

	z = t1^t2^t3;
	
	//更新t1,t2,t3
	//t1 = t1 + s91s92 + s171
	s91 = (ctx->s[2]<<5)|(ctx->s[1]>>27);
	s92 = (ctx->s[2]<<4)|(ctx->s[1]>>28);
	s171 = (ctx->s[5]<<18)|(ctx->s[4]>>14);

	t1 ^= (s91&s92)^s171;

	//t2 = t2 + s175s176 + s264
	s175 = (ctx->s[5]<<14)|(ctx->s[4]>>18);
	s176 = (ctx->s[5]<<13)|(ctx->s[4]>>19);
	s264 = (ctx->s[8]<<9)|(ctx->s[7]>>23);

	t2 ^= (s175&s176)^s264;

	//t3 = t3 + s286s287 + s69
	s286 = (ctx->s[9]<<19)|(ctx->s[8]>>13);
	s287 = (ctx->s[9]<<18)|(ctx->s[8]>>14);
	s69 = (ctx->s[2]<<27)|(ctx->s[1]>>5);

	t3 ^= (s286&s287)^s69;

	// update register 1
	ctx->s[2] = (ctx->s[1])&(0x1FFFFFFF);
	ctx->s[1] = ctx->s[0];
	ctx->s[0] = t3;

	//update register 2
	ctx->s[5] = ctx->s[4]&(0x000FFFFF);
	ctx->s[4] = ctx->s[3];
	ctx->s[3] = t1;

	//update register 3
	ctx->s[9] = ctx->s[8]&(0x00007FFF);
	ctx->s[8] = ctx->s[7];
	ctx->s[7] = ctx->s[6];
	ctx->s[6] = t2;
	//printf("%d  ",z);

	
	return z;
}

 __device__ u8 Trivium_update_funcion_bit(ECRYPT_ctx* ctx)
{
	u32 t1,t2,t3;
	u32 s66,s93,s162,s177,s243,s288,s91,s92,s171,s175,s176,s264,s286,s287,s69;
	u32 z;

	s66 = ((ctx->s[2]<<30)&0x80000000)>>31;//移位以后，只取最高位
	s93 = ((ctx->s[2]<<3)&0x80000000)>>31;
	s162 = ((ctx->s[5]<<27)&0x80000000)>>31;
	s177 = ((ctx->s[5]<<12)&0x80000000)>>31;
	s243 = ((ctx->s[8]<<30)&0x80000000)>>31;
	s288 = ((ctx->s[9]<<17)&0x80000000)>>31;

	//s(66)+s(93)
	t1 = s66^s93;

	//s(162)+s(177)
	t2 = s162^s177;

	//s(243)+s(288)
	t3 = s243^s288;

	z = t1^t2^t3;
	//更新t1,t2,t3
	//t1 = t1 + s91s92 + s171
	s91 = ((ctx->s[2]<<5)&0x80000000)>>31;
	s92 = ((ctx->s[2]<<4)&0x80000000)>>31;
	s171 = ((ctx->s[5]<<18)&0x80000000)>>31;

	t1 ^= (s91&s92)^s171;

	//t2 = t2 + s175s176 + s264
	s175 = ((ctx->s[5]<<14)&0x80000000)>>31;
	s176 = ((ctx->s[5]<<13)&0x80000000)>>31;
	s264 = ((ctx->s[8]<<9)&0x80000000)>>31;

	t2 ^= (s175&s176)^s264;

	//t3 = t3 + s286s287 + s69
	s286 = ((ctx->s[9]<<19)&0x80000000)>>31;
	s287 = ((ctx->s[9]<<18)&0x80000000)>>31;
	s69 = ((ctx->s[2]<<27)&0x80000000)>>31;
	t3 ^= (s286&s287)^s69;
	// update register 1
	//S[0]的左移一位,然后级联上新产生的一个比特//((ctx->s[1]&0x80000000)>>31)
	ctx->s[2]=((ctx->s[2]<<1)|(((ctx->s[1]&0x80000000)>>31)))&(0x1FFFFFFF);
	ctx->s[1]=(ctx->s[1]<<1)|(((ctx->s[0]&0x80000000)>>31));
	ctx->s[0]=(ctx->s[0]<<1)|t3;
	//update register 2
	ctx->s[5]=((ctx->s[5]<<1)|(((ctx->s[4]&0x80000000)>>31)))&(0x000FFFFF);
	ctx->s[4]=(ctx->s[4]<<1)|(((ctx->s[3]&0x80000000)>>31));
	ctx->s[3]=(ctx->s[3]<<1)|t1;
	//update register 3
	ctx->s[9]=((ctx->s[9]<<1)|(((ctx->s[8]&0x80000000)>>31)))&(0x00007FFF);
	ctx->s[8]=(ctx->s[8]<<1)|(((ctx->s[7]&0x80000000)>>31));
	ctx->s[7]=(ctx->s[7]<<1)|(((ctx->s[6]&0x80000000)>>31));
	ctx->s[6]=(ctx->s[6]<<1)|t2;
	return z;
}
  __device__ void ECRYPT_ivsetup_bit( ECRYPT_ctx* ctx,  u32* iv, u32 roundnum)
  {
  u8 i;
  u32 roundnum_word;
  u32 roundnum_bit;
 
  ctx->s[0] = ctx->key[0]^(ctx->key[1]<<8)^(ctx->key[2]<<16)^(ctx->key[3]<<24);
  ctx->s[1] = ctx->key[4]^(ctx->key[5]<<8)^(ctx->key[6]<<16)^(ctx->key[7]<<24);
  ctx->s[2] = ctx->key[8]^(ctx->key[9]<<8);

  ctx->s[3] = iv[0]^(iv[1]<<8)^(iv[2]<<16)^(iv[3]<<24);
  ctx->s[4] = iv[4]^(iv[5]<<8)^(iv[6]<<16)^(iv[7]<<24);
  ctx->s[5] = iv[8]^(iv[9]<<8);

  ctx->s[6] = 0;
  ctx->s[7] = 0;
  ctx->s[8] = 0;
  ctx->s[9] = 0x00007000;
  
  //32*36 = 1152
  roundnum_word=roundnum/32;
  roundnum_bit=roundnum%32;
  for(i=0;i<roundnum_word;i++)
	Trivium_update_funcion_word( ctx);
  for(i=0;i<roundnum_bit;i++)
	Trivium_update_funcion_bit(ctx);
}
 __device__ void ECRYPT_keysetup( ECRYPT_ctx* ctx,   u32* key,  u32 keysize, u32 ivsize)
{
  u8 i;

  ctx->keylen = 10;
  ctx->ivlen = 10;

  for (i = 0; i < ctx->keylen; ++i)
    ctx->key[i] = key[i];
}

 __device__ void ECRYPT_keystream_words( ECRYPT_ctx* ctx,  u32* keystream,  u32 length)               
{
	u32 j;
	u32 z;

	for(j=0;j<length;j++)
	{
		z = Trivium_update_funcion_word(ctx);
		keystream[j] = reverse_word(z);
	}
}

//  __device__ void ECRYPT_keystream_wordsV2(u32* keystream,u32* iv, u32 *key, u32 roundnum)               
//{
//	u32 z1,j;
//	//z = Trivium_update_funcion_word(ctx);
//	//不调用函数直接写
//  u32 roundnum_word;
//  u32 roundnum_bit;
//  u32 t1,t2,t3,i;
//  u32 s[10];
//  u32 s66,s93,s162,s177,s243,s288,s91,s92,s171,s175,s176,s264,s286,s287,s69;
//  u32 z;
// s[0] = key[0]^(key[1]<<8)^(key[2]<<16)^(key[3]<<24);
// s[1] = key[4]^(key[5]<<8)^(key[6]<<16)^(key[7]<<24);
// s[2] = key[8]^(key[9]<<8);
//
// s[3] = iv[0]^(iv[1]<<8)^(iv[2]<<16)^(iv[3]<<24);
// s[4] = iv[4]^(iv[5]<<8)^(iv[6]<<16)^(iv[7]<<24);
// s[5] = iv[8]^(iv[9]<<8);
//
// s[6] = 0;
// s[7] = 0;
// s[8] = 0;
// s[9] = 0x00007000;
//  
// // 32*36 = 1152
//  roundnum_word=roundnum/32;
//  roundnum_bit=roundnum%32;
//  for(i=0;i<roundnum_word;i++)
//  {
//
//	s66 = (s[2]<<30)|(s[1]>>2);//相或之后相当于直接级联
//	s93 = (s[2]<<3)|(s[1]>>29);
//	s162 = (s[5]<<27)|(s[4]>>5);
//	s177 = (s[5]<<12)|(s[4]>>20);
//	s243 = (s[8]<<30)|(s[7]>>2);
//	s288 = (s[9]<<17)| (s[8]>>15);
//
//	t1 = s66^s93;
//
//	t2 = s162^s177;
//
//	t3 = s243^s288;
//
//	z = t1^t2^t3;
//	
//	//更新t1,t2,t3
////	t1 = t1 + s91s92 + s171
//	s91 = (s[2]<<5)|(s[1]>>27);
//	s92 = (s[2]<<4)|(s[1]>>28);
//	s171 = (s[5]<<18)|(s[4]>>14);
//
//	t1 ^= (s91&s92)^s171;
//
////	t2 = t2 + s175s176 + s264
//	s175 = (s[5]<<14)|(s[4]>>18);
//	s176 = (s[5]<<13)|(s[4]>>19);
//	s264 = (s[8]<<9)|(s[7]>>23);
//
//	t2 ^= (s175&s176)^s264;
//
////	t3 = t3 + s286s287 + s69
//	s286 = (s[9]<<19)|(s[8]>>13);
//	s287 = (s[9]<<18)|(s[8]>>14);
//	s69 = (s[2]<<27)|(s[1]>>5);
//
//	t3 ^= (s286&s287)^s69;
//
//	// update register 1
//	s[2] = (s[1])&(0x1FFFFFFF);
//	s[1] =s[0];
//	s[0] = t3;
//
////	update register 2
//	s[5] =s[4]&(0x000FFFFF);
//	s[4] =s[3];
//	s[3] = t1;
//
////	update register 3
//	s[9] =s[8]&(0x00007FFF);
//	s[8] =s[7];
//	s[7] =s[6];
//	s[6] = t2;
//  }
//  if(roundnum_bit!=0)
//  {
//	s66 = (s[2]<<30)|(s[1]>>2);//相或之后相当于直接级联
//	s93 = (s[2]<<3)|(s[1]>>29);
//	s162 = (s[5]<<27)|(s[4]>>5);
//	s177 = (s[5]<<12)|(s[4]>>20);
//	s243 = (s[8]<<30)|(s[7]>>2);
//	s288 = (s[9]<<17)| (s[8]>>15);
//
//	t1 = s66^s93;
//
//	t2 = s162^s177;
//
//	t3 = s243^s288;
//
//	z = t1^t2^t3;
//	z1=z;
//	//更新t1,t2,t3
//	//t1 = t1 + s91s92 + s171
//	s91 = (s[2]<<5)|(s[1]>>27);
//	s92 = (s[2]<<4)|(s[1]>>28);
//	s171 = (s[5]<<18)|(s[4]>>14);
//
//	t1 ^= (s91&s92)^s171;
//
//	//t2 = t2 + s175s176 + s264
//	s175 = (s[5]<<14)|(s[4]>>18);
//	s176 = (s[5]<<13)|(s[4]>>19);
//	s264 = (s[8]<<9)|(s[7]>>23);
//
//	t2 ^= (s175&s176)^s264;
//
//	//t3 = t3 + s286s287 + s69
//	s286 = (s[9]<<19)|(s[8]>>13);
//	s287 = (s[9]<<18)|(s[8]>>14);
//	s69 = (s[2]<<27)|(s[1]>>5);
//
//	t3 ^= (s286&s287)^s69;
//
//	// update register 1
//	s[2] = (s[1])&(0x1FFFFFFF);
//	s[1] =s[0];
//	s[0] = t3;
//
//	//update register 2
//	s[5] =s[4]&(0x000FFFFF);
//	s[4] =s[3];
//	s[3] = t1;
//
//	//update register 3
//	s[9] =s[8]&(0x00007FFF);
//	s[8] =s[7];
//	s[7] =s[6];
//	s[6] = t2;
//  }
//	s66 = (s[2]<<30)|(s[1]>>2);//相或之后相当于直接级联
//	s93 = (s[2]<<3)|(s[1]>>29);
//	s162 = (s[5]<<27)|(s[4]>>5);
//	s177 = (s[5]<<12)|(s[4]>>20);
//	s243 = (s[8]<<30)|(s[7]>>2);
//	s288 = (s[9]<<17)| (s[8]>>15);
//	t1 = s66^s93;
//	t2 = s162^s177;
//	t3 = s243^s288;
//	z = t1^t2^t3;
//	if(roundnum_bit!=0)
//		z=(z1<<roundnum_bit)|(z>>(32-roundnum_bit));
//	keystream[0]=reverse_word(z);
//}



 __device__ void ECRYPT_keystream_wordsV2(u32* keystream,u32* iv, u32 *key, u32 roundnum)               
{
	u32 z1;
	//z = Trivium_update_funcion_word(ctx);
	//不调用函数直接写
  u32 roundnum_word;
  u32 roundnum_bit;
  u32 t1,t2,t3,i;
  u32 s[10];
  //u32 temp1,temp2,temp3,temp4,temp5,temp6,s91,s92,s171,s175,s176,s264,s286,s287,s69;
  u32 temp1,temp2,temp3,temp4,temp5,temp6;
  u32 z;
 s[0] = key[0]^(key[1]<<8)^(key[2]<<16)^(key[3]<<24);
 s[1] = key[4]^(key[5]<<8)^(key[6]<<16)^(key[7]<<24);
 s[2] = key[8]^(key[9]<<8);

 s[3] = iv[0]^(iv[1]<<8)^(iv[2]<<16)^(iv[3]<<24);
 s[4] = iv[4]^(iv[5]<<8)^(iv[6]<<16)^(iv[7]<<24);
 s[5] = iv[8]^(iv[9]<<8);

 s[6] = 0;
 s[7] = 0;
 s[8] = 0;
 s[9] = 0x00007000;
  
 // 32*36 = 1152
  roundnum_word=roundnum/32;
  roundnum_bit=roundnum%32;
  for(i=0;i<roundnum_word;i++)
  {

	temp1 = (s[2]<<30)|(s[1]>>2);//相或之后相当于直接级联
	temp2 = (s[2]<<3)|(s[1]>>29);
	temp3 = (s[5]<<27)|(s[4]>>5);
	temp4 = (s[5]<<12)|(s[4]>>20);
	temp5 = (s[8]<<30)|(s[7]>>2);
	temp6 = (s[9]<<17)| (s[8]>>15);

	t1 = temp1^temp2;

	t2 = temp3^temp4;

	t3 = temp5^temp6;

	//z = t1^t2^t3;
	
	//更新t1,t2,t3
//	t1 = t1 + s91s92 + s171
	temp1 = (s[2]<<5)|(s[1]>>27);
	temp2 = (s[2]<<4)|(s[1]>>28);
	temp3 = (s[5]<<18)|(s[4]>>14);

	t1 ^= (temp1&temp2)^temp3;

//	t2 = t2 + s175s176 + s264
	temp1 = (s[5]<<14)|(s[4]>>18);
	temp2 = (s[5]<<13)|(s[4]>>19);
	temp3 = (s[8]<<9)|(s[7]>>23);

	t2 ^= (temp1&temp2)^temp3;

//	t3 = t3 + s286s287 + s69
	temp1 = (s[9]<<19)|(s[8]>>13);
	temp2 = (s[9]<<18)|(s[8]>>14);
	temp3 = (s[2]<<27)|(s[1]>>5);

	t3 ^= (temp1&temp2)^temp3;

	// update register 1
	s[2] = (s[1])&(0x1FFFFFFF);
	s[1] =s[0];
	s[0] = t3;

//	update register 2
	s[5] =s[4]&(0x000FFFFF);
	s[4] =s[3];
	s[3] = t1;

//	update register 3
	s[9] =s[8]&(0x00007FFF);
	s[8] =s[7];
	s[7] =s[6];
	s[6] = t2;
  }
  if(roundnum_bit!=0)
  {
	temp1 = (s[2]<<30)|(s[1]>>2);//相或之后相当于直接级联
	temp2 = (s[2]<<3)|(s[1]>>29);
	temp3 = (s[5]<<27)|(s[4]>>5);
	temp4 = (s[5]<<12)|(s[4]>>20);
	temp5 = (s[8]<<30)|(s[7]>>2);
	temp6 = (s[9]<<17)| (s[8]>>15);

	t1= temp1^temp2;
	t2= temp3^temp4;
	t3= temp5^temp6;
	z1 = temp1^temp2^temp3^temp4^temp5^temp6;
	//z1=z;
	//更新t1,t2,t3
	//t1 = t1 + s91s92 + s171
	temp1 = (s[2]<<5)|(s[1]>>27);
	temp2 = (s[2]<<4)|(s[1]>>28);
	temp3 = (s[5]<<18)|(s[4]>>14);

	t1 ^= (temp1&temp2)^temp3;

	//t2 = t2 + s175s176 + s264
	temp1 = (s[5]<<14)|(s[4]>>18);
	temp2 = (s[5]<<13)|(s[4]>>19);
	temp3 = (s[8]<<9)|(s[7]>>23);

	t2 ^= (temp1&temp2)^temp3;

	//t3 = t3 + s286s287 + s69
	temp1 = (s[9]<<19)|(s[8]>>13);
	temp2 = (s[9]<<18)|(s[8]>>14);
	temp3 = (s[2]<<27)|(s[1]>>5);

	t3 ^= (temp1&temp2)^temp3;

	// update register 1
	s[2] = (s[1])&(0x1FFFFFFF);
	s[1] =s[0];
	s[0] = t3;

	//update register 2
	s[5] =s[4]&(0x000FFFFF);
	s[4] =s[3];
	s[3] = t1;

	//update register 3
	s[9] =s[8]&(0x00007FFF);
	s[8] =s[7];
	s[7] =s[6];
	s[6] = t2;
  }
	temp1 = (s[2]<<30)|(s[1]>>2);//相或之后相当于直接级联
	temp2 = (s[2]<<3)|(s[1]>>29);
	temp3 = (s[5]<<27)|(s[4]>>5);
	temp4 = (s[5]<<12)|(s[4]>>20);
	temp5 = (s[8]<<30)|(s[7]>>2);
	temp6 = (s[9]<<17)| (s[8]>>15);
	z = temp1^temp2^temp3^temp4^temp5^temp6;
	if(roundnum_bit!=0)
		z=(z1<<roundnum_bit)|(z>>(32-roundnum_bit));
	//keystream[0]=reverse_word(z);
	temp1=0;
	temp1 = ((z&0x000000FF)<<24)^((z&0x0000FF00)<<8)^((z&0x00FF0000)>>8)^((z&0xFF000000)>>24);
	temp1 = ((temp1&0x01010101)<<7)^((temp1&0x02020202)<<5)^((temp1&0x04040404)<<3)^((temp1&0x08080808)<<1)^((temp1&0x10101010)>>1)^((temp1&0x20202020)>>3)^((temp1&0x40404040)>>5)^((temp1&0x80808080)>>7);
	keystream[0]=temp1;
}

 __device__ void ECRYPT_keystream_wordsV3(u32* keystream,u32* iv, u32 *key, u32 roundnum)               
{
	u32 z1;
	//z = Trivium_update_funcion_word(ctx);
	//不调用函数直接写
  u32 roundnum_word;
  u32 roundnum_bit;
  u32 t1,t2,t3,i;
  u32 s0,s1,s2,s3,s4,s5,s6,s7,s8,s9;
  //u32 temp1,temp2,temp3,temp4,temp5,temp6,s91,s92,s171,s175,s176,s264,s286,s287,s69;
  u32 temp1,temp2,temp3,temp4,temp5,temp6;
  u32 z;
 s0 = key[0]^(key[1]<<8)^(key[2]<<16)^(key[3]<<24);
 s1 = key[4]^(key[5]<<8)^(key[6]<<16)^(key[7]<<24);
 s2 = key[8]^(key[9]<<8);

 s3 = iv[0]^(iv[1]<<8)^(iv[2]<<16)^(iv[3]<<24);
 s4 = iv[4]^(iv[5]<<8)^(iv[6]<<16)^(iv[7]<<24);
 s5 = iv[8]^(iv[9]<<8);

 s6 = 0;
 s7 = 0;
 s8 = 0;
 s9 = 0x00007000;
  
 // 32*36 = 1152
  roundnum_word=roundnum/32;
  roundnum_bit=roundnum%32;
  for(i=0;i<roundnum_word;i++)
  {

	temp1 = (s2<<30)|(s1>>2);//相或之后相当于直接级联
	temp2 = (s2<<3)|(s1>>29);
	temp3 = (s5<<27)|(s4>>5);
	temp4 = (s5<<12)|(s4>>20);
	temp5 = (s8<<30)|(s7>>2);
	temp6 = (s9<<17)| (s8>>15);

	t1 = temp1^temp2;//((s2<<30)|(s1>>2))^((s2<<3)|(s1>>29))^(((s2<<5)|(s1>>27))&((s2<<4)|(s1>>28)))^(s5<<18)|(s4>>14);

	t2 = temp3^temp4;//((s5<<27)|(s4>>5))^((s5<<12)|(s4>>20))^((s5<<14)|(s4>>18))&((s5<<13)|(s4>>19))^((s8<<9)|(s7>>23));

	t3 = temp5^temp6;//((s8<<30)|(s7>>2))^((s9<<17)| (s8>>15))^

	//z = t1^t2^t3;
	
	//更新t1,t2,t3
//	t1 = t1 + s91s92 + s171
	temp1 = (s2<<5)|(s1>>27);//(((s2<<5)|(s1>>27))&((s2<<4)|(s1>>28)))^(s5<<18)|(s4>>14);
	temp2 = (s2<<4)|(s1>>28);
	temp3 = (s5<<18)|(s4>>14);

	t1 ^= (temp1&temp2)^temp3;

//	t2 = t2 + s175s176 + s264
	temp1 = (s5<<14)|(s4>>18);//(((s5<<14)|(s4>>18))&((s5<<13)|(s4>>19)))^((s8<<9)|(s7>>23));
	temp2 = (s5<<13)|(s4>>19);
	temp3 = (s8<<9)|(s7>>23);

	t2 ^= (temp1&temp2)^temp3;

//	t3 = t3 + s286s287 + s69
	temp1 = (s9<<19)|(s8>>13);//(()&())^()
	temp2 = (s9<<18)|(s8>>14);
	temp3 = (s2<<27)|(s1>>5);

	t3 ^= (temp1&temp2)^temp3;

	// update register 1
	s2 = (s1)&(0x1FFFFFFF);
	s1 =s0;
	s0 = t3;

//	update register 2
	s5 =s4&(0x000FFFFF);
	s4 =s3;
	s3 = t1;

//	update register 3
	s9 =s8&(0x00007FFF);
	s8 =s7;
	s7 =s6;
	s6 = t2;
  }
  if(roundnum_bit!=0)
  {
	temp1 = (s2<<30)|(s1>>2);//相或之后相当于直接级联
	temp2 = (s2<<3)|(s1>>29);
	temp3 = (s5<<27)|(s4>>5);
	temp4 = (s5<<12)|(s4>>20);
	temp5 = (s8<<30)|(s7>>2);
	temp6 = (s9<<17)| (s8>>15);

	t1= temp1^temp2;
	t2= temp3^temp4;
	t3= temp5^temp6;
	z1 = temp1^temp2^temp3^temp4^temp5^temp6;
	//z1=z;
	//更新t1,t2,t3
	//t1 = t1 + s91s92 + s171
	temp1 = (s2<<5)|(s1>>27);
	temp2 = (s2<<4)|(s1>>28);
	temp3 = (s5<<18)|(s4>>14);

	t1 ^= (temp1&temp2)^temp3;

	//t2 = t2 + s175s176 + s264
	temp1 = (s5<<14)|(s4>>18);
	temp2 = (s5<<13)|(s4>>19);
	temp3 = (s8<<9)|(s7>>23);

	t2 ^= (temp1&temp2)^temp3;

	//t3 = t3 + s286s287 + s69
	temp1 = (s9<<19)|(s8>>13);
	temp2 = (s9<<18)|(s8>>14);
	temp3 = (s2<<27)|(s1>>5);

	t3 ^= (temp1&temp2)^temp3;

	// update register 1
	s2 = (s1)&(0x1FFFFFFF);
	s1 =s0;
	s0 = t3;

	//update register 2
	s5 =s4&(0x000FFFFF);
	s4 =s3;
	s3 = t1;

	//update register 3
	s9 =s8&(0x00007FFF);
	s8 =s7;
	s7 =s6;
	s6 = t2;
  }
	temp1 = (s2<<30)|(s1>>2);//相或之后相当于直接级联
	temp2 = (s2<<3)|(s1>>29);
	temp3 = (s5<<27)|(s4>>5);
	temp4 = (s5<<12)|(s4>>20);
	temp5 = (s8<<30)|(s7>>2);
	temp6 = (s9<<17)| (s8>>15);
	z = temp1^temp2^temp3^temp4^temp5^temp6;
	if(roundnum_bit!=0)
		z=(z1<<roundnum_bit)|(z>>(32-roundnum_bit));
	//keystream[0]=reverse_word(z);
	temp1=0;
	temp1 = ((z&0x000000FF)<<24)^((z&0x0000FF00)<<8)^((z&0x00FF0000)>>8)^((z&0xFF000000)>>24);
	temp1 = ((temp1&0x01010101)<<7)^((temp1&0x02020202)<<5)^((temp1&0x04040404)<<3)^((temp1&0x08080808)<<1)^((temp1&0x10101010)>>1)^((temp1&0x20202020)>>3)^((temp1&0x40404040)>>5)^((temp1&0x80808080)>>7);
	keystream[0]=temp1;
}

 __device__ void ECRYPT_keystream_wordsV4(u32* keystream, u32 *key, u32 roundnum,u32 cube[], u32 dim, u32 k, u32 loc)               
{
	u32 z1;
	//z = Trivium_update_funcion_word(ctx);
	//不调用函数直接写
  u32 roundnum_word;
  u32 roundnum_bit;
  u32 t1,t2,t3,i,j,l;
  u32 s0,s1,s2,s3,s4,s5,s6,s7,s8,s9;
  //u32 temp1,temp2,temp3,temp4,temp5,temp6,s91,s92,s171,s175,s176,s264,s286,s287,s69;
  u32 temp1,temp2,temp3,temp4,temp5,temp6;
  u32 z;
  u32 iv[10];
  for(i=0;i<10;i++)
	  iv[i]=0;
  i=k;
  for (j=0;j<dim;j++) 
			iv[cube[j]>>3] |= ( ( (i>>j) & 0x00000001 ) << (cube[j] & 0x07) );
	 j=loc;
	for(l=0;l<6;l++)
	{
		i=dim+l;
		iv[cube[i]>>3]|=(j&0x01)<<(cube[i]&0x07);
		j>>=1;
	}
 s0 = key[0]^(key[1]<<8)^(key[2]<<16)^(key[3]<<24);
 s1 = key[4]^(key[5]<<8)^(key[6]<<16)^(key[7]<<24);
 s2 = key[8]^(key[9]<<8);

 s3 = iv[0]^(iv[1]<<8)^(iv[2]<<16)^(iv[3]<<24);
 s4 = iv[4]^(iv[5]<<8)^(iv[6]<<16)^(iv[7]<<24);
 s5 = iv[8]^(iv[9]<<8);

 s6 = 0;
 s7 = 0;
 s8 = 0;
 s9 = 0x00007000;
  
 // 32*36 = 1152
  roundnum_word=roundnum/32;
  roundnum_bit=roundnum%32;
  for(i=0;i<roundnum_word;i++)
  {

	temp1 = (s2<<30)|(s1>>2);//相或之后相当于直接级联
	temp2 = (s2<<3)|(s1>>29);
	temp3 = (s5<<27)|(s4>>5);
	temp4 = (s5<<12)|(s4>>20);
	temp5 = (s8<<30)|(s7>>2);
	temp6 = (s9<<17)| (s8>>15);

	t1 = temp1^temp2;//((s2<<30)|(s1>>2))^((s2<<3)|(s1>>29))^(((s2<<5)|(s1>>27))&((s2<<4)|(s1>>28)))^(s5<<18)|(s4>>14);

	t2 = temp3^temp4;//((s5<<27)|(s4>>5))^((s5<<12)|(s4>>20))^((s5<<14)|(s4>>18))&((s5<<13)|(s4>>19))^((s8<<9)|(s7>>23));

	t3 = temp5^temp6;//((s8<<30)|(s7>>2))^((s9<<17)| (s8>>15))^

	//z = t1^t2^t3;
	
	//更新t1,t2,t3
//	t1 = t1 + s91s92 + s171
	temp1 = (s2<<5)|(s1>>27);//(((s2<<5)|(s1>>27))&((s2<<4)|(s1>>28)))^(s5<<18)|(s4>>14);
	temp2 = (s2<<4)|(s1>>28);
	temp3 = (s5<<18)|(s4>>14);

	t1 ^= (temp1&temp2)^temp3;

//	t2 = t2 + s175s176 + s264
	temp1 = (s5<<14)|(s4>>18);//(((s5<<14)|(s4>>18))&((s5<<13)|(s4>>19)))^((s8<<9)|(s7>>23));
	temp2 = (s5<<13)|(s4>>19);
	temp3 = (s8<<9)|(s7>>23);

	t2 ^= (temp1&temp2)^temp3;

//	t3 = t3 + s286s287 + s69
	temp1 = (s9<<19)|(s8>>13);//(()&())^()
	temp2 = (s9<<18)|(s8>>14);
	temp3 = (s2<<27)|(s1>>5);

	t3 ^= (temp1&temp2)^temp3;

	// update register 1
	s2 = (s1)&(0x1FFFFFFF);
	s1 =s0;
	s0 = t3;

//	update register 2
	s5 =s4&(0x000FFFFF);
	s4 =s3;
	s3 = t1;

//	update register 3
	s9 =s8&(0x00007FFF);
	s8 =s7;
	s7 =s6;
	s6 = t2;
  }
  if(roundnum_bit!=0)
  {
	temp1 = (s2<<30)|(s1>>2);//相或之后相当于直接级联
	temp2 = (s2<<3)|(s1>>29);
	temp3 = (s5<<27)|(s4>>5);
	temp4 = (s5<<12)|(s4>>20);
	temp5 = (s8<<30)|(s7>>2);
	temp6 = (s9<<17)| (s8>>15);

	t1= temp1^temp2;
	t2= temp3^temp4;
	t3= temp5^temp6;
	z1 = temp1^temp2^temp3^temp4^temp5^temp6;
	//z1=z;
	//更新t1,t2,t3
	//t1 = t1 + s91s92 + s171
	temp1 = (s2<<5)|(s1>>27);
	temp2 = (s2<<4)|(s1>>28);
	temp3 = (s5<<18)|(s4>>14);

	t1 ^= (temp1&temp2)^temp3;

	//t2 = t2 + s175s176 + s264
	temp1 = (s5<<14)|(s4>>18);
	temp2 = (s5<<13)|(s4>>19);
	temp3 = (s8<<9)|(s7>>23);

	t2 ^= (temp1&temp2)^temp3;

	//t3 = t3 + s286s287 + s69
	temp1 = (s9<<19)|(s8>>13);
	temp2 = (s9<<18)|(s8>>14);
	temp3 = (s2<<27)|(s1>>5);

	t3 ^= (temp1&temp2)^temp3;

	// update register 1
	s2 = (s1)&(0x1FFFFFFF);
	s1 =s0;
	s0 = t3;

	//update register 2
	s5 =s4&(0x000FFFFF);
	s4 =s3;
	s3 = t1;

	//update register 3
	s9 =s8&(0x00007FFF);
	s8 =s7;
	s7 =s6;
	s6 = t2;
  }
	temp1 = (s2<<30)|(s1>>2);//相或之后相当于直接级联
	temp2 = (s2<<3)|(s1>>29);
	temp3 = (s5<<27)|(s4>>5);
	temp4 = (s5<<12)|(s4>>20);
	temp5 = (s8<<30)|(s7>>2);
	temp6 = (s9<<17)| (s8>>15);
	z = temp1^temp2^temp3^temp4^temp5^temp6;
	if(roundnum_bit!=0)
		z=(z1<<roundnum_bit)|(z>>(32-roundnum_bit));
	//keystream[0]=reverse_word(z);
	temp1=0;
	temp1 = ((z&0x000000FF)<<24)^((z&0x0000FF00)<<8)^((z&0x00FF0000)>>8)^((z&0xFF000000)>>24);
	temp1 = ((temp1&0x01010101)<<7)^((temp1&0x02020202)<<5)^((temp1&0x04040404)<<3)^((temp1&0x08080808)<<1)^((temp1&0x10101010)>>1)^((temp1&0x20202020)>>3)^((temp1&0x40404040)>>5)^((temp1&0x80808080)>>7);
	keystream[0]=temp1;
}
 
 __global__ void genkeystream_thd(u32 cube[],u32 roundnum ,u32 *c,u32 loadkey[10],u32 offset,u32 dim,u32 k)
{
	//__shared__ u32 cache[1024];
	//__shared__ u32 cube_d[40],key_d[10];
	//__shared__ u32 iv[10];
	u32 i=0,j=0,iv[10];//loadkey[10]={0},cube[20]={1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20};
	u32 keystream[1];
	u32 tid;
	//i=k;
	for(j=0;j<10;j++)
		iv[j]=0;	
	j=k;
	for(i=0;i<4;i++)
	{
		tid=dim+i;
		iv[cube[tid]>>3]|=(j&0x01)<<(cube[tid]&0x07);
		j>>=1;
	}
	tid=threadIdx.x+blockIdx.x*blockDim.x+offset;//多次调用genkey,每个线程只块生成512个输出留
	i=tid;
	for (j=0;j<dim;j++) 
		iv[cube[j]>>3] |= ( ( (i>>j) & 0x00000001 ) << (cube[j] & 0x07) );
	ECRYPT_keystream_wordsV3(keystream,iv,loadkey,roundnum);
	c[tid-offset]=keystream[0];//生成32比特
	__syncthreads();
}

  __global__ void genkeystream_thd_32(u32 cube[],u32 roundnum ,u32 *c,u32 loadkey[10],unsigned __int64 offset,u32 dim,u32 k)
{
	//__shared__ u32 cache[1024];
	//__shared__ u32 cube_d[40],key_d[10];
	//__shared__ u32 iv[10];
	unsigned __int64 i=0,j=0,l,m;
	u32 iv[10];//loadkey[10]={0},cube[20]={1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20};
	u32 keystream[1];
	unsigned __int64 tid;
	u32 streambit=0;
	//i=k;
	for(j=0;j<10;j++)
		iv[j]=0;	
	j=k;
	for(i=0;i<7;i++)
	{
		tid=dim+i;
		iv[cube[tid]>>3]|=(j&0x01)<<(cube[tid]&0x07);
		j>>=1;
	}
	tid=(threadIdx.x+blockIdx.x*blockDim.x+offset)*32;//多次调用genkey,每个线程只块生成512个输出留
	i=tid;
	for(i=tid;i<tid+32;i++)//loopnum要除掉32大概
	{
		for (j=0;j<dim;j++) 
			iv[cube[j]>>3] |= ( ( (i>>j) & 0x00000001 ) << (cube[j] & 0x07) );
		ECRYPT_keystream_wordsV3(keystream,iv,loadkey,roundnum);
		streambit|=(keystream[0]&0x01)<<(i-tid);//后产生的在高位
		for(j=0;j<10;j++)
			iv[j]=0;	
		j=k;
		for(l=0;l<7;l++)
		{
			m=dim+l;
			iv[cube[m]>>3]|=(j&0x01)<<(cube[m]&0x07);
			j>>=1;
		}
	}
	c[threadIdx.x+blockIdx.x*blockDim.x]=streambit;//生成32比特
	__syncthreads();
}

   __global__ void genkeystream_thd_128(u32 cube[],u32 roundnum ,u32 *c,u32 loadkey[10],u32 offset,u32 dim,u32 k)
{
	//__shared__ u32 cache[1024];
	//__shared__ u32 cube_d[40],key_d[10];
	//__shared__ u32 iv[10];
	unsigned __int64 i=0,j=0,l,m,n;
	u32 iv[10];//loadkey[10]={0},cube[20]={1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20};
	u32 keystream[1];
	unsigned __int64 tid;
	u32 streambit[4]={0};
	//i=k;
	for(j=0;j<10;j++)
		iv[j]=0;	
	j=k;
	for(i=0;i<6;i++)
	{
		tid=dim+i;
		iv[cube[tid]>>3]|=(j&0x01)<<(cube[tid]&0x07);
		j>>=1;
	}
	tid=(threadIdx.x+blockIdx.x*blockDim.x+offset)*128;//多次调用genkey,每个线程只块生成512个输出留
	i=tid;
	for(n=0;n<4;n++)
	{
		tid=tid+n*32;
		streambit[n]=0;
		for(i=tid;i<tid+32;i++)//loopnum要除掉32大概
		{
			for (j=0;j<dim;j++) 
				iv[cube[j]>>3] |= ( ( (i>>j) & 0x00000001 ) << (cube[j] & 0x07) );
			ECRYPT_keystream_wordsV3(keystream,iv,loadkey,roundnum);
			streambit[n]|=(keystream[0]&0x01)<<(i-tid);
			for(j=0;j<10;j++)
				iv[j]=0;	
			j=k;
			for(l=0;l<6;l++)
			{
				m=dim+l;
				iv[cube[m]>>3]|=(j&0x01)<<(cube[m]&0x07);
				j>>=1;
			}
		}
		//j=(threadIdx.x+blockIdx.x*blockDim.x)*4+m;
		//c[threadIdx.x+blockIdx.x*blockDim.x]=streambit;
		c[(threadIdx.x+blockIdx.x*blockDim.x)*4+n]=streambit[n];
	}
	/*c[(threadIdx.x+blockIdx.x*blockDim.x)*4+0]=streambit[0];
	c[(threadIdx.x+blockIdx.x*blockDim.x)*4+1]=streambit[1];
	c[(threadIdx.x+blockIdx.x*blockDim.x)*4+2]=streambit[2];
	c[(threadIdx.x+blockIdx.x*blockDim.x)*4+3]=streambit[3];*/
//	c[(threadIdx.x+blockIdx.x*blockDim.x)]=streambit;//生成32比特
	__syncthreads();
}
 //直接将,所有key拷贝进去,然后分别弄就好
__global__  void sum_cube_word(u32  dim, u32 *cube,u32 roundnum ,u32 *c,u32 loadkey[10])
{
	__shared__ u32 cache[threadsPerBlock];
	unsigned __int64 i=0,j=0;
	u32 iv[10];
	u32 keystream[1];
	u32 keystream_sum=0;
//	loopnum= (unsigned __int64 ) pow((double)(2),(double)(dim));
	//loopnum= (unsigned __int64 ) pow(2.0,(double) (dim));
	i=threadIdx.x+blockIdx.x*blockDim.x;
	for(j=0;j<10;j++)
		iv[j]=0;	
	while(i<(U64C(0x01)<<dim))
	//while(i<loopnum)
	{
		for (j=0;j<dim;j++) 
			iv[cube[j]>>3] |= ( ( (i>>j) & 0x00000001 ) << (cube[j] & 0x07) );
		
		ECRYPT_keystream_wordsV3(keystream,iv,loadkey,roundnum);
		keystream_sum ^= keystream[0];
		//重置iv
		for (j=0;j<10;j++) 
			iv[j]= 0;
		i+=blockDim.x*gridDim.x;
	}
	cache[threadIdx.x]=keystream_sum;
	__syncthreads();
	i=blockDim.x>>1;
	while(i!=0)
	{
		if(threadIdx.x<i)
			cache[threadIdx.x]^=cache[threadIdx.x+i];
		__syncthreads();
		i=i>>1;
	}
	if(threadIdx.x==0)
		c[blockIdx.x]=cache[0];
}


__global__  void sum_cube_word_32(u32  dim, u32 *cube,u32 roundnum ,u32 *c,u32 loadkey[10])
{
	__shared__ u32 cache[threadsPerBlock];
	unsigned __int64 i=0,j=0,k=0;
	u32 iv[10];
	u32 keystream[1];
	u32 keystream_sum=0;
//	loopnum= (unsigned __int64 ) pow((double)(2),(double)(dim));
	//loopnum= (unsigned __int64 ) pow(2.0,(double) (dim));
	i=(threadIdx.x+blockIdx.x*blockDim.x)*32;
	for(j=0;j<10;j++)
		iv[j]=0;	
	while(i<(U64C(0x01)<<dim))
	//while(i<loopnum)
	{

		///每加一次间隔，做32比特
		for(k=i;k<i+32;k++)
		{
			
			for (j=0;j<dim;j++) 
				iv[cube[j]>>3] |= ( ( (k>>j) & 0x00000001 ) << (cube[j] & 0x07) );
		
			ECRYPT_keystream_wordsV3(keystream,iv,loadkey,roundnum);
			keystream_sum ^= keystream[0];
			//重置iv
			for (j=0;j<10;j++) 
				iv[j]= 0;
		}

		i+=(blockDim.x*gridDim.x)*32;
	}
	cache[threadIdx.x]=keystream_sum;
	__syncthreads();
	i=blockDim.x>>1;
	while(i!=0)
	{
		if(threadIdx.x<i)
			cache[threadIdx.x]^=cache[threadIdx.x+i];
		__syncthreads();
		i=i>>1;
	}
	if(threadIdx.x==0)
		c[blockIdx.x]=cache[0];
}
//二次插值专用, kn表示用哪一个密钥,loc表示取值
__global__  void sum_cube_word_sf(u32  dim, u32 *cube,u32 roundnum ,u32 *c,u32 loadkey[10], u32 kn, u32 loc)
{
	__shared__ u32 cache[threadsPerBlock];
	unsigned __int64 i=0,j=0;
	u32 iv[10],tempkey[10];
	u32 keystream[1];
	u32 keystream_sum=0;
//	loopnum= (unsigned __int64 ) pow((double)(2),(double)(dim));
	//loopnum= (unsigned __int64 ) pow(2.0,(double) (dim));

	//根据 kn和loc更改
	/*loadkey[(i)>>3]=loadkey[(i)>>3]&((0xFF)^(0x01)<<((i)&0x07));
	loadkey[(i+1)>>3]=loadkey[(i+1)>>3]&((0xFF)^(0x01)<<((i+1)&0x07));*/
	
	for(i=0;i<10;i++)
		tempkey[i]=loadkey[i];



	/*tempkey[kn>>3]=tempkey[kn>>3]&((0xFF)^((loc/2)<<(0x07&kn)));
	tempkey[(kn+1)>>3]=tempkey[(kn+1)>>3]&((0xFF)^((loc%2)<<(0x07&(kn+1))));*/
	//先恢复成00，然后再或上

	tempkey[kn>>3]=tempkey[kn>>3]&((0xFF)^((0x01)<<(0x07&kn)));
	tempkey[(kn+1)>>3]=tempkey[(kn+1)>>3]&((0xFF)^((0x01)<<(0x07&(kn+1))));
	
	
	tempkey[kn>>3]=tempkey[kn>>3]|(((loc/2)<<(0x07&kn)));
	tempkey[(kn+1)>>3]=tempkey[(kn+1)>>3]|(((loc%2)<<(0x07&(kn+1))));


	i=threadIdx.x+blockIdx.x*blockDim.x;

	/*if(i==0)
	{
			for(j=0;j<10;j++)
					printf("%d,",tempkey[j]);
			printf("\n");
			printf("%d\n",loc);
	}*/
	for(j=0;j<10;j++)
		iv[j]=0;	
	while(i<(U64C(0x01)<<dim))
	//while(i<loopnum)
	{
		for (j=0;j<dim;j++) 
			iv[cube[j]>>3] |= ( ( (i>>j) & 0x00000001 ) << (cube[j] & 0x07) );
		
		ECRYPT_keystream_wordsV3(keystream,iv,tempkey,roundnum);
		keystream_sum ^= keystream[0];
		//重置iv
		for (j=0;j<10;j++) 
			iv[j]= 0;
		i+=blockDim.x*gridDim.x;
	}

	cache[threadIdx.x]=keystream_sum;
	__syncthreads();
	i=blockDim.x>>1;
	while(i!=0)
	{
		if(threadIdx.x<i)
			cache[threadIdx.x]^=cache[threadIdx.x+i];
		__syncthreads();
		i=i>>1;
	}
	if(threadIdx.x==0)
		c[blockIdx.x]=cache[0];
}
__host__ u8 linearity_test_randomkey_word(u32 cube[], u8 dim, u32 roundnum,u8 linearity_test_res[])
{
	u32 chosenkey[48+1][10],i,keynum,partialsum[1024]={0},value[48]={0},j;
	//数组长度还有待商榷,需要根据维数重新确定
	//需要传递的参数,随机密钥,cube,roundnum,还需要再申请一块空间用于存放返回的部分求和值,在主机上进行求和,增加一个参数
	u32 **chosenkey_dev,*partialsum_dev;
	u32 blocksPerGrid= 64;//(0x01<<dim)/threadsPerBlock;
	u32 constantterm=0;
	u32 length,check=0,check_con=0;
	u32 *cube_dev,res,check_bit,flag;
	//size_t pitch;
	keynum=48;
	clock_t t1,t2;

	length=blocksPerGrid;//((0x01<<dim)>>4)>>8;
	///length=((0x01<<dim);
	/*printf("cube of dim %d is being tested \n",dim);
	for(i=0;i<dim;i++)
		printf("%d,",cube[i]);
	printf("\n");*/
	t1=clock_t();
	cudaMalloc((void **)&cube_dev,dim*sizeof(u32));
	cudaMalloc((void **)&partialsum_dev,length*sizeof(u32));
	chosenkey_dev=(u32 **)malloc(sizeof(u32 *)*(keynum+1));
	for(i=0;i<keynum+1;i++)
	{
		cudaMalloc((void **) &chosenkey_dev[i],10*sizeof(u32));
		
	}

	for(i=1;i<keynum+1;i+=3)
	{
		choose_random_key(chosenkey[i]);
		choose_random_key(chosenkey[i+1]);
		for(j=0;j<10;j++)
			chosenkey[i+2][j]=chosenkey[i][j]^chosenkey[i+1][j];
	}
	for(i=0;i<10;i++)
		chosenkey[0][i]=0;
	//将主机端的数据拷贝到设备端
	cudaMemcpy(cube_dev,cube,dim*sizeof(u32),cudaMemcpyHostToDevice);
	for(i=0;i<keynum+1;i++)
	{
		cudaMemcpy(chosenkey_dev[i],chosenkey[i],sizeof(u32)*10,cudaMemcpyHostToDevice);
	}
	cudaEvent_t start,stop;
	cudaEventCreate(&start);  
    cudaEventCreate(&stop);  
    cudaEventRecord(start,0);  
//	sum_cube_word<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_dev,roundnum,partialsum_dev,chosenkey_dev[0]);
	sum_cube_word_32<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_dev,roundnum,partialsum_dev,chosenkey_dev[0]);
	//sum_cube_wordV2<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_dev,roundnum,partialsum_dev,0);
	cudaMemcpy(partialsum,partialsum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
	cudaEventRecord(stop,0);  
    cudaEventSynchronize(stop);
	float tm;  
    cudaEventElapsedTime(&tm,start,stop);  
    printf("GPU Elapsed time:%.6f ms.\n",tm);  
	for(i=0;i<length;i++)
		constantterm^=partialsum[i];


	//实现密钥复用。
	for(j=0;j<keynum;j+=3)
	{
		//key1
		//sum_cube_word<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_dev,roundnum,partialsum_dev,chosenkey_dev[j+1]);
		sum_cube_word_32<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_dev,roundnum,partialsum_dev,chosenkey_dev[j+1]);
		cudaMemcpy(partialsum,partialsum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
		for(i=0;i<length;i++)
			value[j]^=partialsum[i];
		//key2
		//sum_cube_word<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_dev,roundnum,partialsum_dev,chosenkey_dev[j+2]);
		sum_cube_word_32<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_dev,roundnum,partialsum_dev,chosenkey_dev[j+2]);
		cudaMemcpy(partialsum,partialsum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
		for(i=0;i<length;i++)
			value[j+1]^=partialsum[i];
		//key1+key2
		//sum_cube_word<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_dev,roundnum,partialsum_dev,chosenkey_dev[j+3]);
		sum_cube_word_32<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_dev,roundnum,partialsum_dev,chosenkey_dev[j+3]);
		cudaMemcpy(partialsum,partialsum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
		for(i=0;i<length;i++)
			value[j+2]^=partialsum[i];
		//
		check_con = check_con| (constantterm^value[j]);
		check = check | (constantterm^value[j]^value[j+1]^value[j+2]);
		if(check == 0xFFFFFFFF)
			break;
	}
	if(check==0xFFFFFFFF)//要改成FFFFFFFF？？？？？
	{
		for(i=0;i<32;i++)
			linearity_test_res[i] = 0;
		/*for(i=0;i<32;i++)
			printf("%d,",linearity_test_res[i]);
		printf("\n");*/
		return 0;
	}
	else{
		res = 2;
		for(i=0;i<32;i++)
		{
			check_bit = (check>>i) & 0x01;
			if(check_bit==0x01)
				linearity_test_res[i]=0;
			else
			{
				flag = 0;
				//检查是否常值
				if((check_con>>i) & 0x01)
					linearity_test_res[i] = 1;
				else
					linearity_test_res[i] = 2;
			}	
		}
	}
	/*for(i=0;i<32;i++)
			printf("%d,",linearity_test_res[i]);
	printf("\n");*/
	//u32 **chosenkey_dev,*partialsum_dev;
	cudaFree(cube_dev);
	cudaFree(partialsum_dev);
	for(i=0;i<keynum+1;i++)
		cudaFree(chosenkey_dev[i]);
	//cudaEvent
	cudaEventDestroy(start);
	cudaEventDestroy(stop);
	return res;
}

__host__ void RetrieveSum(u32 cube[], u8 dim, u32 roundnum,u32 chosenkey[][10], u32 sum_res[])
{
	u32 i,keynum,partialsum[1024]={0},value[100]={0},j;
	//数组长度还有待商榷,需要根据维数重新确定
	//需要传递的参数,随机密钥,cube,roundnum,还需要再申请一块空间用于存放返回的部分求和值,在主机上进行求和,增加一个参数
	u32 **chosenkey_dev,*partialsum_dev;
	u32 blocksPerGrid= 64;//(0x01<<dim)/threadsPerBlock;
	u32 constantterm=0;
	u32 length,check=0,check_con=0;
	u32 *cube_dev,res,check_bit,flag;
	//size_t pitch;
	keynum=20;
	clock_t t1,t2;

	length=blocksPerGrid;//((0x01<<dim)>>4)>>8;

	t1=clock_t();
	cudaMalloc((void **)&cube_dev,dim*sizeof(u32));
	cudaMalloc((void **)&partialsum_dev,length*sizeof(u32));
	chosenkey_dev=(u32 **)malloc(sizeof(u32 *)*(keynum));
	for(i=0;i<keynum;i++)
	{
		cudaMalloc((void **) &chosenkey_dev[i],10*sizeof(u32));
		
	}
	//将主机端的数据拷贝到设备端
	cudaMemcpy(cube_dev,cube,dim*sizeof(u32),cudaMemcpyHostToDevice);
	for(i=0;i<keynum;i++)
	{
		cudaMemcpy(chosenkey_dev[i],chosenkey[i],sizeof(u32)*10,cudaMemcpyHostToDevice);
	}

	//实现密钥复用。
	for(j=0;j<keynum;j++)
	{
		//key j
		sum_cube_word_32<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_dev,roundnum,partialsum_dev,chosenkey_dev[j]);
		cudaMemcpy(partialsum,partialsum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
		for(i=0;i<length;i++)
			value[j]^=partialsum[i];

		sum_res[j]=value[j]&0x01;
		
	}
	
	cudaFree(cube_dev);
	cudaFree(partialsum_dev);
	for(i=0;i<keynum+1;i++)
		cudaFree(chosenkey_dev[i]);
}

__host__ void GetSum()
{
	//cube也放在这里
	//随机生成
	u32 roundnum=709, randomkey[1000][10];
	u32 keynum=20;
	u8 lin_res[32],flag;
	u32 cube[100][80]={{73,71,70,66,57,55,51,49,47,43,40,39,36,34,32,31,19,16,12,11,6,3,0},{71,32,9,66,2,70,11,59,72,20,56,41,58,43,77,5,74,25,6,47,33,68,17,36},{33,71,32,63,40,37,4,30,5,76,7,50,73,3,15,12,41,59,47,2,51,35,56,65,22},
{12,43,59,70,61,42,66,64,48,40,35,55,19,67,77,23,54,17,72,63,7,79,4,57},
{33,71,32,63,40,37,4,30,5,76,7,50,9,73,3,15,12,59,47,2,35,56,65,22,27,31},
{75,71,67,35,47,55,4,5,62,32,17,65,50,37,58,48,26,0,23,33,77,20,38,60,7,79,14,64},
{75,74,71,67,35,47,55,5,62,32,17,50,37,58,48,0,23,77,20,60,7,79,14,41,64}};
	u32 i,j,k,recsum[1000];
	u32 cubenum=5;
	u8 dimlist[100]={23,24,25,25,26,28,25};
	FILE *RecKey, *RecSum,*fp;
	RecKey=fopen("RecKey","a+");
	RecSum=fopen("RecSum","a+");
	// record the chosen key
	for(i=0;i<keynum;i++)
	{
		choose_random_key(randomkey[i]);
		for(j=0;j<10;j++)
			fprintf(RecKey,"%x,", randomkey[i][j]);
		fprintf(RecKey,"\n");
	}
	for(i=0;i<1000;i++)
	{
		for(j=0;j<10;j++)
			randomkey[i][j]=0x00;
		randomkey[i][2]=0x02;
	}
	// get sum for each cube

	for(i=0;i<cubenum;i++)
	{
		// compute the sum of the chosen 100 random keys
		printf("%d,",i);
		//
		flag=linearity_test_randomkey_word(cube[i],dimlist[i],roundnum,lin_res);
		printf("*******%d*******",flag);
		RetrieveSum(cube[i],dimlist[i],roundnum,randomkey,recsum);

		for(j=0;j<dimlist[i];j++)
		{
			fprintf(RecSum,"%u,",cube[i][j]);
		}
		fprintf(RecSum,"   ");
		for(j=0;j<keynum;j++)
			fprintf(RecSum,"%d,",recsum[j]);
		fprintf(RecSum,"\n");
	}
	fclose(RecSum);
	fclose(RecKey);
}

__host__ void verifygivencube(u32 cube[], u8 dim, u32 roundnum, u8 outindex)
{
	u8 i,result=0x00;
	u8 linearity_test_res[32];
	
	clock_t t1,t2;
	for(i=0;i<dim;i++)
		printf("%d,",cube[i]);
	printf("\n");
	t1=clock_t();
	
	result=linearity_test_randomkey_word(cube, dim, roundnum,linearity_test_res);

	t2=clock_t();
	printf("%d ms\n",t2-t1);
	for(i=0;i<32;i++)
		printf("%d,",linearity_test_res[i]);
	printf("\n");
	if(linearity_test_res[outindex]==1){
		printf("superpoly is linear! \n");
			//printfsuperpoly(cube, dim,roundnum, outindex);
		//printfsuperpoly(cube,dim,roundnum,outindex);
	}
	else if(linearity_test_res[outindex] ==2)
		printf("superpoly is a constant! \n");
	else
		printf("superpoly is nonlinear!\n");
}
__host__ void write_superpoly_subcube(FILE * fp,u32 cube[], u8 dim,u32 roundnum, u8 outindex)
{
	u32 chosenkey[80+1][10],i,keynum,partialsum[1024]={0},value[81]={0},j;
	//数组长度还有待商榷,需要根据维数重新确定
	//需要传递的参数,随机密钥,cube,roundnum,还需要再申请一块空间用于存放返回的部分求和值,在主机上进行求和,增加一个参数
	u32 **randkey_dev,*psum_dev;
	u32 blocksPerGrid= 64;//(0x01<<dim)/threadsPerBlock;
	u32 constantterm=0;
	u32 length;
	u32 *cube_d;
	u8 coeff[81]={0};
	//size_t pitch;
	keynum=80;
	length=blocksPerGrid;//((0x01<<dim)>>4)>>8;
	///length=((0x01<<dim);
	cudaMalloc((void **)&cube_d,dim*sizeof(u32));
	cudaMalloc((void **)&psum_dev,length*sizeof(u32));
	randkey_dev=(u32 **)malloc(sizeof(u32 *)*(keynum+1));
	for(i=0;i<keynum+1;i++)
	{
		cudaMalloc((void **) &randkey_dev[i],10*sizeof(u32));
		
	}

	for(i=1;i<keynum+1;i++)
	{
		for(j=0;j<10;j++)
			chosenkey[i][j]=0;
		chosenkey[i][(i-1)>>3]=(0x01)<<((i-1)&0x07);
	}
	for(i=0;i<10;i++)
		chosenkey[0][i]=0;
	//将主机端的数据拷贝到设备端
	cudaMemcpy(cube_d,cube,dim*sizeof(u32),cudaMemcpyHostToDevice);
	for(i=0;i<keynum+1;i++)
	{
		cudaMemcpy(randkey_dev[i],chosenkey[i],sizeof(u32)*10,cudaMemcpyHostToDevice);
	}
	cudaEvent_t start,stop;
	cudaEventCreate(&start);  
    cudaEventCreate(&stop);  
    cudaEventRecord(start,0);  
	sum_cube_word<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_d,roundnum,psum_dev,randkey_dev[0]);
	//sum_cube_word_32<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_d,roundnum,psum_dev,randkey_dev[0]);
	//sum_cube_wordV2<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_d,roundnum,psum_dev,0);
	cudaEventRecord(stop,0);  
    cudaEventSynchronize(stop);  
    float tm;  
    cudaEventElapsedTime(&tm,start,stop);  
    printf("GPU Elapsed time:%.6f ms.\n",tm);  

	cudaMemcpy(partialsum,psum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
	for(i=0;i<length;i++)
		constantterm^=partialsum[i];
	coeff[0]=(constantterm>>outindex)&(0x01);
	fprintf(fp,"%d",coeff[0]);
	for(j=1;j<keynum+1;j++)
	{
		sum_cube_word<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_d,roundnum,psum_dev,randkey_dev[j]);
		cudaMemcpy(partialsum,psum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
		for(i=0;i<length;i++)
			value[j]^=partialsum[i];
		coeff[j]=((value[j]>>outindex)&0x01)^coeff[0];
		if(coeff[j]==1)
			fprintf(fp,"+x%d",j-1);
		
	}
	 fprintf(fp, "\n");
	//u32 **randkey_dev,*psum_dev;
	 cudaFree(cube_d);
	cudaFree(psum_dev);
	for(i=0;i<keynum+1;i++)
		cudaFree(randkey_dev[i]);
	free(randkey_dev);
	cudaEventDestroy(start);
	cudaEventDestroy(stop);
}

//u8 outputsubcubes(u32 cube[], u8 dim, u32 roundnum, u8 outindex, u32 pos, char filename[])
u8 outputsubcubes(u32 cube[], u8 dim, u32 roundnum, u8 outindex, unsigned __int64 pos, char filename[])
{
	u8 i,j;
	u32 *subcube;
	u8 subdim;
	u8 result=0x00;
	u8 linearity_test_res[32];
	FILE * fp;
	subcube = (u32 *)malloc(dim*sizeof(u32));

	fp = fopen(filename,"a+");
	subdim = 0;
	for (j=0;j<dim;j++) {
		if((pos>>j) & 0x00000001)
		{
			subcube[subdim] = cube[j];
			subdim++;
		}
	}	

	//result=linearity_test_randomkey_word(subcube, subdim, roundnum,linearity_test_res);
	//result=1;
	//linearity_test_res[outindex]=1;
	//if(linearity_test_res[outindex]==1)
	if(1)
	{
		if(firstoutput)
		{
			fprintf(fp, "\n\nround = %d*32, dim = %d,",roundnum,dim);
			fprintf(fp, "\nmother cube: ");
			for(i=0;i<dim;i++)
				fprintf(fp, "%d,",cube[i]);
			firstoutput = 0;
		}
		fprintf(fp, "\noutindex = %d, subdim = %d", outindex,subdim);
		fprintf(fp,"\nTYPE1: subcube: ");
		for(j=0;j<subdim;j++)
			fprintf(fp,"%d,",subcube[j]);
		fprintf(fp,"	");
		write_superpoly_subcube(fp,subcube, subdim,roundnum, outindex);
		fclose(fp);
		free(subcube);
		return 1;
	}
	else
	{
		fclose(fp);
		free(subcube);
		return 0;
	}
/*	else if(linearity_test_res[outindex] ==2)
	{
		if(firstoutput)
		{
			fprintf(fp, "\n\nround = %d*32, dim = %d,",roundnum,dim);
			fprintf(fp, "\nmother cube: ");
			for(i=0;i<dim;i++)
				fprintf(fp, "%d,",cube[i]);
			firstoutput = 0;
		}
		fprintf(fp, "\noutindex = %d, subdim = %d", outindex,subdim);
		fprintf(fp,"\nsubcube: ");
		for(j=0;j<subdim;j++)
			fprintf(fp,"%d,",subcube[j]);
		fprintf(fp,"	");
		fprintf(fp,"constant");
	}*/

}



 __host__ void construc_truth_table_dynamicV2(u32 cube[], u32 dim, u32 roundnum,u32 **table,u32 rownum, u32 columnnum,u32 loadkey[10])
{
	////每一个线程块中只有一个线程,然后每一个线程产生512个输出密钥流,大循环的次数就是2^dim/512/线程块的个数

	u32 i=0,j=0,k=0,iv[10]={0};
	//u32 keystream[1];
	u32 temp=0,*partialstream_dev,*partialstream,*loadkey_dev,*iv_dev;//partialstream用于存储在设备端产生的密钥流序列
	u32 bolcknum=64,threadnum=512,loopnum;
	//dim3 bolckdim;
	u32 *cube_dev;
	for(i=0;i<rownum;i++)
		for(j=0;j<columnnum;j++)
			table[i][j] = 0;

	//确定大循环次数
	loopnum=(U64C(0x01)<<dim)/bolcknum/threadnum;
	//分配空间
	partialstream=(u32 *)malloc(sizeof(u32 )*bolcknum*threadnum);
	cudaMalloc((void **)&partialstream_dev,sizeof(u32 )*bolcknum*threadnum);
	cudaMalloc((void **)&cube_dev,sizeof(u32)*dim);
	cudaMalloc((void **)&loadkey_dev,sizeof(u32 )*10);
	cudaMalloc((void **)&iv_dev,sizeof(u32 )*10);
	//cudaMallocPitch((void**)&cube_dev,&pitch_cube,sizeof(u8)*dim,1);
	//cudaMallocPitch((void**)&loadkey_dev,&pitch_key,sizeof(u32)*10,1);
	//拷贝数据
	
	cudaMemcpy(cube_dev,cube,sizeof(u32)*dim,cudaMemcpyHostToDevice);
	cudaMemcpy(loadkey_dev,loadkey,sizeof(u32)*10,cudaMemcpyHostToDevice);
	cudaMemcpy(iv_dev,iv,sizeof(u32)*10,cudaMemcpyHostToDevice);
	//cudaMemcpy2D(cube_dev,pitch_cube,cube,sizeof(u8)*dim,sizeof(u8)*dim,1,cudaMemcpyHostToDevice);
	//cudaMemcpy2D(loadkey_dev,pitch_key,loadkey,sizeof(u32)*10,sizeof(u32)*10,1,cudaMemcpyHostToDevice);
	cudaEvent_t start,stop;
	cudaEventCreate(&start);  
    cudaEventCreate(&stop);  
    float tm;  
  
	/*用给定的cube产生密钥流*/
	//采用的块并行,但是线程并行的话
	for (i=0;i<loopnum;i++)
	{
		//sum_cube_word<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_dev,roundnum,partialsum_dev,chosenkey_dev[j+3]);
		temp=i*bolcknum*threadnum;//偏移量
		cudaEventRecord(start,0); 
		//genkeystream_thd<<<bolcknum,threadnum>>>(cube_dev,roundnum,partialstream_dev,loadkey_dev,temp,dim);
		cudaEventRecord(stop,0);  
		cudaEventSynchronize(stop); 
		cudaEventElapsedTime(&tm,start,stop);  
	//	printf("GPU Elapsed time:%.6f ms.\n",tm);
		cudaMemcpy(partialstream,partialstream_dev,sizeof(u32)*bolcknum*threadnum,cudaMemcpyDeviceToHost);//如果不是一口气做32轮的话应该还可以
		//
		//
		//for(k=0;k<bolcknum*threadnum;k++)
		for(k=0;k<bolcknum*threadnum;k++)
		{
			temp=i*bolcknum*threadnum+k;//0-256,每一次生成1024个输出流,可能优化效果有限
		for(j=0;j<1;j++)
			table[j][temp>>5] |= ((partialstream[k]>>j)&0x00000001)<<(temp&0x0000001F);
		}
	}
}

u32 linearity_test_dynamicV2(u32 cube[], u32 dim, u32 roundnum,char filename[])
{
	u32 i,j,a,b,key[10];
	u32 **constantterm;//常数项
	u32 numrandomkey = 16*2;  // 两两一组
	u32 randomkey[16*2][10];
	u32 **value0;//每个随机密钥的函数值
	u32 **value1;//每个随机密钥的函数值
	u32 **twokeysum; //两个随机密钥异或的函数值
	u32 **ANF,**ANF2;
	u32 **check,**check1;
	FILE *fp2,*Sdim;
	u32 flag,flag1,subdim;
	u32 rownum = 32,cubenum=0;
	u32 columnum = U64C(0x01)<<(dim-5);
	clock_t t1,t2;
	fp2=fopen("CRec.txt","a+");
	Sdim=fopen("subdim.txt","a+");
	constantterm = (u32 **)malloc(rownum*sizeof(u32*));
	for(i=0;i<rownum;i++)
		constantterm[i]=(u32*)malloc(columnum*sizeof(u32));

	value0 = (u32 **)malloc(rownum*sizeof(u32*));
	for(i=0;i<rownum;i++)
		value0[i]=(u32*)malloc(columnum*sizeof(u32));

	value1 = (u32 **)malloc(rownum*sizeof(u32*));
	for(i=0;i<rownum;i++)
		value1[i]=(u32*)malloc(columnum*sizeof(u32));

	twokeysum = (u32 **)malloc(rownum*sizeof(u32*));
	for(i=0;i<rownum;i++)
		twokeysum[i]=(u32*)malloc(columnum*sizeof(u32));

	ANF = (u32 **)malloc(rownum*sizeof(u32*));
	ANF2 = (u32 **)malloc(rownum*sizeof(u32*));
	for(i=0;i<rownum;i++)
	{
		ANF[i]=(u32*)malloc(columnum*sizeof(u32));
		ANF2[i]=(u32*)malloc(columnum*sizeof(u32));
	}

	check = (u32 **)malloc(rownum*sizeof(u32*));
	check1 = (u32 **)malloc(rownum*sizeof(u32*));
	for(i=0;i<rownum;i++)
	{
		check[i]=(u32*)malloc(columnum*sizeof(u32));
		check1[i]=(u32*)malloc(columnum*sizeof(u32));
	}

	for(a=0;a<rownum;a++)
		for(b=0;b<columnum;b++)
		{
				check[a][b] = 0;
				check1[a][b] = 0;
		}

	for(i=0;i<10;i++)
		key[i]= 0;
	//ECRYPT_keysetup(&ctx, key, 80,80);
	construc_truth_table_dynamicV2(cube, dim, roundnum,constantterm,rownum,columnum,key);

	for(i=0;i<numrandomkey;i++)
		choose_random_key(randomkey[i]);

	for(j=0;j<numrandomkey;j=j+2)
	{
		for(i=0;i<10;i++)
			key[i] = randomkey[j][i];
		//ECRYPT_keysetup(&ctx, key, 80,80);
		construc_truth_table_dynamicV2(cube, dim, roundnum,value0,rownum,columnum,key);

		for(i=0;i<10;i++)
			key[i]=randomkey[j+1][i];
		//ECRYPT_keysetup(&ctx, key, 80,80);
		construc_truth_table_dynamicV2(cube, dim, roundnum,value1,rownum,columnum,key);

		for(i=0;i<10;i++)
			key[i]=randomkey[j][i]^randomkey[j+1][i];
		//ECRYPT_keysetup(&ctx, key, 80,80);
		t1=clock();
		construc_truth_table_dynamicV2(cube, dim, roundnum,twokeysum,rownum,columnum,key);
		t2=clock();
		printf("%dms\n",t2-t1);
		for(a=0;a<rownum;a++){
			for(b=0;b<columnum;b++)
			{
				ANF[a][b] = constantterm[a][b]^value0[a][b]^value1[a][b]^twokeysum[a][b];
				ANF2[a][b] = constantterm[a][b]^value0[a][b];
			}
			Moebius(ANF[a], U64C(0x01)<<dim);
			Moebius(ANF2[a], U64C(0x01)<<dim);
			for(b=0;b<columnum;b++)
			{
				check[a][b] |= ANF[a][b];
				check1[a][b] |= ANF2[a][b];
			}
		}
	}
	fprintf(fp2,"*************************\n");
	for(a=0;a<rownum;a++)
	{
		fprintf(fp2,"\nOutputBit %d is being tested.....\n",a);
		for(b=0;b<(U64C(0x01)<<dim);b++)
		{
			flag = check[a][b>>5] & ((U64C(0x01))<<(b&0x0000001F));
			flag1 = check1[a][b>>5] & ((U64C(0x01))<<(b&0x0000001F));
			//flag1=1;
			subdim=0;
			if((flag==0)&&(flag1!=0))//通过线性检测,但是不通过常值检测的
			{
				for(i=0;i<dim;i++)
				{
					if(((b>>i)&0x01) ==1)
					{
						fprintf(fp2,"%d,",cube[i]);
						subdim++;
					}
				}
				fprintf(fp2,"\n");
				fprintf(Sdim,"%d,",subdim);
				outputsubcubes(cube,dim,roundnum,a,b,filename);
			}
		}

	//printf("OutputBit %d is being tested.....",a);
	}
	
	for(i=0;i<rownum;i++)
	{
		free(constantterm[i]);
		free(value0[i]);
		free(value1[i]);
		free(twokeysum[i]);
		free(ANF[i]);
		free(check[i]);
	}
	free(constantterm);
	free(value0);
	free(value1);
	free(twokeysum);
	free(ANF);
	free(check);
	fclose(fp2);
	fclose(Sdim);
	return cubenum;
}

//cut memory
 __host__ void construc_truth_table_dynamic_CutM(u32 cube[], u32 dim, u32 roundnum,u32 **table,u32 rownum, u32 columnnum,u32 loadkey[10],u32 lk)
{
	////每一个线程块中只有一个线程,然后每一个线程产生512个输出密钥流,大循环的次数就是2^dim/512/线程块的个数

	u32 i=0,j=0,k=0,iv[10]={0};
	//u32 keystream[1];
	u32 temp=0,*partialstream_dev,*partialstream,*loadkey_dev,*iv_dev;//partialstream用于存储在设备端产生的密钥流序列
	u32 bolcknum=64,threadnum=512,loopnum;
	//dim3 bolckdim;
	u32 *cube_dev;
	//for()

	//确定大循环次数
	loopnum=(U64C(0x01)<<(dim-6))/bolcknum/threadnum;
	//分配空间
	partialstream=(u32 *)malloc(sizeof(u32 )*bolcknum*threadnum);
	cudaMalloc((void **)&partialstream_dev,sizeof(u32 )*bolcknum*threadnum);
	cudaMalloc((void **)&cube_dev,sizeof(u32)*dim);
	cudaMalloc((void **)&loadkey_dev,sizeof(u32 )*10);
	cudaMalloc((void **)&iv_dev,sizeof(u32 )*10);
	//cudaMallocPitch((void**)&cube_dev,&pitch_cube,sizeof(u8)*dim,1);
	//cudaMallocPitch((void**)&loadkey_dev,&pitch_key,sizeof(u32)*10,1);
	//拷贝数据
	
	cudaMemcpy(cube_dev,cube,sizeof(u32)*dim,cudaMemcpyHostToDevice);
	cudaMemcpy(loadkey_dev,loadkey,sizeof(u32)*10,cudaMemcpyHostToDevice);
	cudaMemcpy(iv_dev,iv,sizeof(u32)*10,cudaMemcpyHostToDevice);
	//cudaMemcpy2D(cube_dev,pitch_cube,cube,sizeof(u8)*dim,sizeof(u8)*dim,1,cudaMemcpyHostToDevice);
	//cudaMemcpy2D(loadkey_dev,pitch_key,loadkey,sizeof(u32)*10,sizeof(u32)*10,1,cudaMemcpyHostToDevice);
	cudaEvent_t start,stop;
	cudaEventCreate(&start);  
    cudaEventCreate(&stop);  
    float tm;  
  
	/*用给定的cube产生密钥流*/
	//采用的块并行,但是线程并行的话
	dim=dim-4;
	for (i=0;i<loopnum;i++)
	{
		//sum_cube_word<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_dev,roundnum,partialsum_dev,chosenkey_dev[j+3]);
		temp=i*bolcknum*threadnum;//偏移量
		cudaEventRecord(start,0); 
		genkeystream_thd<<<bolcknum,threadnum>>>(cube_dev,roundnum,partialstream_dev,loadkey_dev,temp,dim,lk);
		cudaEventRecord(stop,0);  
		cudaEventSynchronize(stop); 
		cudaEventElapsedTime(&tm,start,stop);  
		//
		cudaMemcpy(partialstream,partialstream_dev,sizeof(u32)*bolcknum*threadnum,cudaMemcpyDeviceToHost);
	//	printf("GPU Elapsed time:%.6f ms.\n",tm);
		//
		for(k=0;k<bolcknum*threadnum;k++)
		{
			temp=i*bolcknum*threadnum+k;//0-256,每一次生成1024个输出流,可能优化效果有限
		for(j=0;j<1;j++)
			table[j][temp>>5] ^= ((partialstream[k]>>j)&0x00000001)<<(temp&0x0000001F);
		}
	}
}


  __host__ void construc_truth_table_dynamic_CutM_32(u32 cube[], u32 dim, u32 roundnum,u32 **table,u32 rownum, u32 columnnum,u32 loadkey[10],u32 lk)
{
	////每一个线程块中只有一个线程,然后每一个线程产生512个输出密钥流,大循环的次数就是2^dim/512/线程块的个数

	unsigned __int64 i=0,j=0,k=0, temp=0;
	u32 iv[10]={0};
	//u32 keystream[1];
	u32 *partialstream_dev,*partialstream,*loadkey_dev,*iv_dev;//partialstream用于存储在设备端产生的密钥流序列
	u32 bolcknum=64,threadnum=512;//00.06
	//u32 bolcknum=8,threadnum=32;
	unsigned __int64 loopnum;
	//dim3 bolckdim;
	u32 *cube_dev;
	//for()

	//确定大循环次数
	loopnum=(U64C(0x01)<<(dim-7))/bolcknum/threadnum/32;
	//分配空间
	partialstream=(u32 *)malloc(sizeof(u32 )*bolcknum*threadnum);
	cudaMalloc((void **)&partialstream_dev,sizeof(u32 )*bolcknum*threadnum);
	cudaMalloc((void **)&cube_dev,sizeof(u32)*dim);
	cudaMalloc((void **)&loadkey_dev,sizeof(u32 )*10);
	cudaMalloc((void **)&iv_dev,sizeof(u32 )*10);
	//cudaMallocPitch((void**)&cube_dev,&pitch_cube,sizeof(u8)*dim,1);
	//cudaMallocPitch((void**)&loadkey_dev,&pitch_key,sizeof(u32)*10,1);
	//拷贝数据
	
	cudaMemcpy(cube_dev,cube,sizeof(u32)*dim,cudaMemcpyHostToDevice);
	cudaMemcpy(loadkey_dev,loadkey,sizeof(u32)*10,cudaMemcpyHostToDevice);
	cudaMemcpy(iv_dev,iv,sizeof(u32)*10,cudaMemcpyHostToDevice);
	//cudaMemcpy2D(cube_dev,pitch_cube,cube,sizeof(u8)*dim,sizeof(u8)*dim,1,cudaMemcpyHostToDevice);
	//cudaMemcpy2D(loadkey_dev,pitch_key,loadkey,sizeof(u32)*10,sizeof(u32)*10,1,cudaMemcpyHostToDevice);
	//cudaEvent_t start,stop;
//	cudaEventCreate(&start);  
  //  cudaEventCreate(&stop);  
    float tm;  
  
	/*用给定的cube产生密钥流*/
	//采用的块并行,但是线程并行的话
	dim=dim-7;
	for (i=0;i<loopnum;i++)
	{
		//sum_cube_word<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_dev,roundnum,partialsum_dev,chosenkey_dev[j+3]);
		temp=i*bolcknum*threadnum;//偏移量
	//	cudaEventRecord(start,0); 
		genkeystream_thd_32<<<bolcknum,threadnum>>>(cube_dev,roundnum,partialstream_dev,loadkey_dev,temp,dim,lk);
	//	genkeystream_thd_128<<<bolcknum,threadnum>>>(cube_dev,roundnum,partialstream_dev,loadkey_dev,temp,dim,lk);//
	//	cudaEventRecord(stop,0);  
	//	cudaEventSynchronize(stop); 
//		cudaEventElapsedTime(&tm,start,stop);  
		//
		cudaMemcpy(partialstream,partialstream_dev,sizeof(u32)*bolcknum*threadnum,cudaMemcpyDeviceToHost);
	//	printf("GPU Elapsed time:%.6f ms.\n",tm);
		//
		for(k=0;k<bolcknum*threadnum;k++)
		{
			temp=i*bolcknum*threadnum+k;//0-256,每一次生成1024个输出流,可能优化效果有限
		for(j=0;j<1;j++)
			//table[j][temp>>5] ^= ((partialstream[k]>>j)&0x00000001)<<(temp&0x0000001F);
			table[j][temp]^=partialstream[k];
		}
	}
	cudaFree(cube_dev);
	cudaFree(partialstream_dev);
	//cudaFree(partialstream);
	cudaFree(iv_dev);
	cudaFree(loadkey);
	free(partialstream);
}
 ///singleRound
u32 linearity_test_dynamicV3(u32 cube[], u32 dim, u32 roundnum,char filename[])
{
	u32 i,j,a,b,key[10],k,partdim,l,n;
	u32 **constantterm,**constantterm1,**check1,**value0;//常数项
	u32 *Filter1,*Filter, Flength=32768, *Fcheck,*Fcheck1,*Fpos;
	u32 numrandomkey = 16*2;  // 两两一组
	u32 randomkey[16*2][10];
	u32 **check,**ANF;//还是需要排除常数项
	FILE *fp2,*Sdim;
	u32 flag,flag1,subdim;
	u32 rownum = 1,cubenum=0;
	u32 columnum = U64C(0x01)<<(dim-5);
	fp2=fopen("CRec.txt","a+");
	Sdim=fopen("subdim.txt","a+");
	n=Flength;
	constantterm = (u32 **)malloc(rownum*sizeof(u32*));
	Filter1=(u32 *) malloc(sizeof(u32)*Flength);
	Filter=(u32 *) malloc(sizeof(u32)*Flength);
	Fcheck=(u32 *) malloc(sizeof(u32)*Flength);
	Fcheck1=(u32 *) malloc(sizeof(u32)*Flength);
	Fpos=(u32 *) malloc(sizeof(u32)*Flength);
	for(i=0;i<rownum;i++)
		constantterm[i]=(u32*)malloc(columnum*sizeof(u32));

	constantterm1 = (u32 **)malloc(rownum*sizeof(u32*));
	for(i=0;i<rownum;i++)
		constantterm1[i]=(u32*)malloc(columnum*sizeof(u32));
	
	check1 = (u32 **)malloc(rownum*sizeof(u32*));
	value0 = (u32 **)malloc(rownum*sizeof(u32*));
	ANF = (u32 **)malloc(rownum*sizeof(u32*));
	for(i=0;i<rownum;i++)
	{
		ANF[i]=(u32*)malloc(columnum*sizeof(u32));
		check1[i]=(u32*)malloc(columnum*sizeof(u32));
		value0[i]=(u32*)malloc(columnum*sizeof(u32));
	}

	check = (u32 **)malloc(rownum*sizeof(u32*));
	for(i=0;i<rownum;i++)
	{
		check[i]=(u32*)malloc(columnum*sizeof(u32));
	}

	for(a=0;a<rownum;a++)
		for(b=0;b<columnum;b++)
		{
				check[a][b] = 0;
				check1[a][b] = 0;
		}

	//在这里加一个循环
	//partdim=4;
	partdim=4;
	for(i=0;i<numrandomkey;i++)
		choose_random_key(randomkey[i]);
	//dim-=partdim;
	for(k=0;k<Flength;k++)
	{
		Fcheck[k]=0;
		Fcheck1[k]=0;
		Filter[k]=0;
		Filter1[k]=0;
	}
	for(j=0;j<numrandomkey;j=j+2)
	{
		Flength=0;
		for(k=0;k<16;k++)
		{
			//取cube,然后计算常值
			if((k&0x01)==0)
			{
				for(a=0;a<rownum;a++)
					for(b=0;b<columnum;b++)
					{
							constantterm[a][b] = 0;
							value0[a][b] = 0;
							constantterm1[a][b] = 0;
					}
			}
			for(i=0;i<10;i++)
				key[i]= 0;
			construc_truth_table_dynamic_CutM(cube, dim, roundnum,constantterm,rownum,columnum,key,k);
			for(i=0;i<10;i++)
				key[i] = randomkey[j][i];
			construc_truth_table_dynamic_CutM(cube, dim, roundnum,value0,rownum,columnum,key,k);

			for(i=0;i<10;i++)
				key[i]=randomkey[j+1][i];
			construc_truth_table_dynamic_CutM(cube, dim, roundnum,constantterm1,rownum,columnum,key,k);
			for(i=0;i<10;i++)
				key[i]=randomkey[j][i]^randomkey[j+1][i];
			construc_truth_table_dynamic_CutM(cube, dim, roundnum,constantterm1,rownum,columnum,key,k);
			for(a=0;a<rownum;a++){
				for(b=0;b<columnum;b++)
				{
					constantterm1[a][b] = constantterm[a][b]^constantterm1[a][b]^value0[a][b];
					value0[a][b]= constantterm[a][b]^value0[a][b];
				}
				Moebius(constantterm1[a], U64C(0x01)<<dim);
				Moebius(value0[a], U64C(0x01)<<dim);
			}
			//做完Moebius变换之后, 需要进行筛选, 如何高效的筛选, 组合数生成器,遍历家判断显然是不可取的,当然在低维的时候怎么都行
			//假设筛选完的存放在Filter[],其长度为Flength
			
			//m=(0x01<<dim)<<partdim;


			//m=(0x01<<(dim-partdim));
			//a=0;//用以控制轮数
			//for(b=0;b<m;b++)
			//{
			//	weight=0;
			//	l=b;
			//	for(i=0;i<dim;i++)
			//	{
			//		weight+=(l&0x01);
			//		l>>=1;
			//	}
			//	if(weight>9)
			//	{
			//		Filter[Flength>>5]|=((constantterm1[a][b>>5]>>(b&0x01f))&0x01)<<(Flength&0x1f);
			//		Filter1[Flength>>5]|=((value0[a][b>>5]>>(b&0x01f))&0x01)<<(Flength&0x1f);
			//		//Fpos[Flength]=(b<<4)|k;
			//		Fpos[Flength]=(k<<12)|b;
			//		Flength++;
			//	}
			//}

		}
		//
		for(k=0;k<Flength;k++)
		{
			Fcheck[k]|=Filter[k];
			Fcheck1[k]|=Filter1[k];
		}
	
			for(b=0;b<n;b++)
			{
				Filter[b]=0;
				Filter1[b]=0;
			}
	}
	fprintf(fp2,"*************************\n");
	dim+=partdim;
	for(l=0;l<Flength;l++)
	{
		//b=Fpos[l];
		b=l;
		flag = Fcheck[b>>5] & ((U64C(0x01))<<(b&0x0000001F));
		flag1 = Fcheck1[b>>5] & ((U64C(0x01))<<(b&0x0000001F));
		//flag1=1;
		subdim=0;
		//if((flag==0))//通过线性检测,但是不通过常值检测的
		b=Fpos[l];
		if((flag==0)&&(flag1!=0))//通过线性检测,但是不通过常值检测的
		{
			for(i=0;i<dim;i++)
			{
				if(((b>>i)&0x01) ==1)
				{
					fprintf(fp2,"%d,",cube[i]);
					subdim++;
				}
			}
			fprintf(fp2,"\n");
			fprintf(Sdim,"%d,",subdim);
			outputsubcubes(cube,dim,roundnum,a,b,filename);
		}
	}
	
	for(i=0;i<rownum;i++)
	{
		free(constantterm[i]);
		free(constantterm1[i]);
		free(ANF[i]);
	}
	free(constantterm);
	free(constantterm1);
	free(ANF);
	free(check);
	fclose(fp2);
	fclose(Sdim);
	return cubenum;
}

//固定4个iv变元
u32 linearity_test_dynamicV4(u32 cube[], u32 dim, u32 roundnum,char filename[])
{
	u32 i,j,a,b,key[10],k,partdim,l,Flength;
	u32 **constantterm,**constantterm1,**check1,**value0;//常数项
	u32 numrandomkey = 16*2;  // 两两一组
	u32 randomkey[16*2][10];
	u32 **check,**ANF;//还是需要排除常数项
	FILE *fp2,*Sdim;
	u32 flag,flag1,subdim;
	u32 rownum = 1,cubenum=0;
	u32 columnum = U64C(0x01)<<(dim-5-4);
	fp2=fopen("CRec.txt","a+");
	Sdim=fopen("subdim.txt","a+");
	constantterm = (u32 **)malloc(rownum*sizeof(u32*));
	
	for(i=0;i<rownum;i++)
		constantterm[i]=(u32*)malloc(columnum*sizeof(u32));

	constantterm1 = (u32 **)malloc(rownum*sizeof(u32*));
	for(i=0;i<rownum;i++)
		constantterm1[i]=(u32*)malloc(columnum*sizeof(u32));
	
	check1 = (u32 **)malloc(rownum*sizeof(u32*));
	value0 = (u32 **)malloc(rownum*sizeof(u32*));
	ANF = (u32 **)malloc(rownum*sizeof(u32*));
	for(i=0;i<rownum;i++)
	{
		ANF[i]=(u32*)malloc(columnum*sizeof(u32));
		check1[i]=(u32*)malloc(columnum*sizeof(u32));
		value0[i]=(u32*)malloc(columnum*sizeof(u32));
	}

	check = (u32 **)malloc(rownum*sizeof(u32*));
	for(i=0;i<rownum;i++)
	{
		check[i]=(u32*)malloc(columnum*sizeof(u32));
	}

	for(a=0;a<rownum;a++)
		for(b=0;b<columnum;b++)
		{
				check[a][b] = 0;
				check1[a][b] = 0;
				constantterm[a][b]=0;
		}

	//在这里加一个循环
	//partdim=4;
	partdim=4;
	for(i=0;i<numrandomkey;i++)
		choose_random_key(randomkey[i]);
	//dim-=partdim;


	//常数项
	for(k=0;k<16;k++)
	{
		for(i=0;i<10;i++)
			key[i]= 0;
		construc_truth_table_dynamic_CutM(cube, dim, roundnum,constantterm,rownum,columnum,key,k);
	}
	for(j=0;j<numrandomkey;j=j+2)
	{
		for(a=0;a<rownum;a++)
			for(b=0;b<columnum;b++)
			{
					value0[a][b] = 0;
					constantterm1[a][b] = 0;
			}
		for(k=0;k<16;k++)
		{
			for(i=0;i<10;i++)
				key[i] = randomkey[j][i];
			construc_truth_table_dynamic_CutM(cube, dim, roundnum,value0,rownum,columnum,key,k);
		}
		for(k=0;k<16;k++)
		{
			for(i=0;i<10;i++)
				key[i]=randomkey[j+1][i];
			construc_truth_table_dynamic_CutM(cube, dim, roundnum,constantterm1,rownum,columnum,key,k);
		}
		for(k=0;k<16;k++)
		{
			for(i=0;i<10;i++)
				key[i]=randomkey[j][i]^randomkey[j+1][i];
			construc_truth_table_dynamic_CutM(cube, dim, roundnum,constantterm1,rownum,columnum,key,k);
		}
		for(a=0;a<rownum;a++)
		{
			for(b=0;b<columnum;b++)
			{
				constantterm1[a][b] = constantterm[a][b]^constantterm1[a][b]^value0[a][b];
				value0[a][b]= constantterm[a][b]^value0[a][b];
			}
			Moebius(constantterm1[a], U64C(0x01)<<(dim-partdim));
			Moebius(value0[a], U64C(0x01)<<(dim-partdim));;
			for(b=0;b<columnum;b++)
			{
				check[a][b] |= constantterm1[a][b];
				check1[a][b] |= value0[a][b];
			}
		}
			
		}
	fprintf(fp2,"*************************\n");
	
	Flength=(0x01)<<(dim-partdim);
	//dim+=partdim;
	a=0;
	for(l=0;l<Flength;l++)
	{
		b=l;
		flag = check[0][b>>5] & ((U64C(0x01))<<(b&0x0000001F));
		flag1 = check1[0][b>>5] & ((U64C(0x01))<<(b&0x0000001F));
		//flag1=1;
		subdim=0;
		b=0x0f<<(dim-partdim)|b;
		//if((flag==0))//通过线性检测,但是不通过常值检测的
		if((flag==0)&&(flag1!=0))//通过线性检测,但是不通过常值检测的
		{
			for(i=0;i<dim;i++)
			{
				if(((b>>i)&0x01) ==1)
				{
					fprintf(fp2,"%d,",cube[i]);
					subdim++;
				}
			}
			fprintf(fp2,"\n");
			fprintf(Sdim,"%d,",subdim);
			outputsubcubes(cube,dim,roundnum,a,b,filename);
		}
	}
	
	for(i=0;i<rownum;i++)
	{
		free(constantterm[i]);
		free(constantterm1[i]);
		free(ANF[i]);
	}
	free(constantterm);
	free(constantterm1);
	free(ANF);
	free(check);
	fclose(fp2);
	fclose(Sdim);
	return cubenum;
}


////先筛选, 然后做一个16元的Meobius变换

u32 linearity_test_dynamicV5(u32 cube[], u32 dim, u32 roundnum,char filename[])
{
	u32 i,j,a,b,key[10],k,partdim=4,weight,l,m,n,Sz,Pos;
	u32 **constantterm,**constantterm1,**value0;//常数项
	u32 **Filter1,**Filter, Flength=156227, **Fcheck,**Fcheck1,**Fpos;
	u32 numrandomkey = 16*2;  // 两两一组
	u32 randomkey[16*2][10];
	FILE *fp2,*Sdim;
	u32 flag,flag1,subdim;
	u32 rownum = 1,cubenum=0;
	u32 columnum = U64C(0x01)<<(dim-5-partdim);
	clock_t t1,t2;
	fp2=fopen("CRec.txt","a+");
	Sdim=fopen("subdim.txt","a+");
	n=Flength;
	constantterm = (u32 **)malloc(rownum*sizeof(u32*));
	Filter1=(u32 **) malloc(sizeof(u32*)*Flength);
	Filter=(u32 **) malloc(sizeof(u32*)*Flength);//2维数组,用于保存每一个部分函数的ANF(筛选后)
	Fcheck=(u32 **) malloc(sizeof(u32*)*Flength);
	Fcheck1=(u32 **) malloc(sizeof(u32*)*Flength);
	Fpos=(u32 **) malloc(sizeof(u32*)*Flength);
	for(i=0;i<rownum;i++)
		constantterm[i]=(u32*)malloc(columnum*sizeof(u32));

	for(i=0;i<16;i++)
	{
		Filter1[i]=(u32*)malloc(Flength*sizeof(u32));
		Filter[i]=(u32*)malloc(Flength*sizeof(u32));
		Fpos[i]=(u32*)malloc(Flength*sizeof(u32));
		Fcheck[i]=(u32*)malloc(Flength*sizeof(u32));
		Fcheck1[i]=(u32*)malloc(Flength*sizeof(u32));
	}
	constantterm1 = (u32 **)malloc(rownum*sizeof(u32*));
	for(i=0;i<rownum;i++)
		constantterm1[i]=(u32*)malloc(columnum*sizeof(u32));
	
	value0 = (u32 **)malloc(rownum*sizeof(u32*));
	for(i=0;i<rownum;i++)
	{
		value0[i]=(u32*)malloc(columnum*sizeof(u32));
	}


	//在这里加一个循环
	//partdim=4;
	partdim=4;
	for(i=0;i<numrandomkey;i++)
		choose_random_key(randomkey[i]);
	//dim-=partdim;
	for(a=0;a<16;a++)
		for(b=0;b<Flength;b++)
		{
			Filter[a][b]=0;
			Filter1[a][b]=0;
			Fpos[a][b]=0;
			Fcheck[a][b]=0;
			Fcheck1[a][b]=0;
		}

		//先筛选出来
		m=(0x01<<(dim-partdim));
		Flength=0;
		for(b=0;b<m;b++)
			{
				weight=0;
				l=b;
				for(i=0;i<dim;i++)
				{
					weight+=(l&0x01);
					l>>=1;
				}
				if(weight>dim-7)
				{
				//	Filter[k][Flength>>5]|=((constantterm1[a][b>>5]>>(b&0x01f))&0x01)<<(Flength&0x1f);
				//	Filter1[k][Flength>>5]|=((value0[a][b>>5]>>(b&0x01f))&0x01)<<(Flength&0x1f);
					//Fpos[Flength]=(b<<4)|k;
					Fpos[0][Flength]=(0<<(dim-partdim))|b;
					Flength++;
				}
			}
	
		//dim=dim+4;
	//t1=clock();
	for(j=0;j<numrandomkey;j=j+2)
	{
		//Flength=0;
		t1=clock();
		for(k=0;k<16;k++)
		{
		//	Flength=0;
		
			for(a=0;a<rownum;a++)
				for(b=0;b<columnum;b++)
				{
						constantterm[a][b] = 0;
						value0[a][b] = 0;
						constantterm1[a][b] = 0;
				}
			//取cube,然后计算常值
		for(i=0;i<10;i++)
			key[i]= 0;
		construc_truth_table_dynamic_CutM_32(cube, dim, roundnum,constantterm,rownum,columnum,key,k);
		//construc_truth_table_dynamicV2(cube, dim-6, roundnum,constantterm,rownum,columnum,key);
		for(i=0;i<10;i++)
			key[i] = randomkey[j][i];
		construc_truth_table_dynamic_CutM_32(cube, dim, roundnum,value0,rownum,columnum,key,k);

			for(i=0;i<10;i++)
				key[i]=randomkey[j+1][i];
		construc_truth_table_dynamic_CutM_32(cube, dim, roundnum,constantterm1,rownum,columnum,key,k);
			for(i=0;i<10;i++)
				key[i]=randomkey[j][i]^randomkey[j+1][i];
    	construc_truth_table_dynamic_CutM_32(cube, dim, roundnum,constantterm1,rownum,columnum,key,k);
			for(a=0;a<rownum;a++){
				for(b=0;b<columnum;b++)
				{
					constantterm1[a][b] = constantterm[a][b]^constantterm1[a][b]^value0[a][b];
					value0[a][b]= constantterm[a][b]^value0[a][b];
				}
				Moebius(constantterm1[a], U64C(0x01)<<(dim-partdim));
				Moebius(value0[a], U64C(0x01)<<(dim-partdim));
			}
			a=0;
			for(b=0;b<Flength;b++)
			{
					//Fpos[k][b]=(k<<(dim-partdim))|((Fpos[0][b]&()partdim)>>partdim);
				//高4位就是0，直接或上就可以
				Fpos[k][b]=(k<<(dim-partdim))|(Fpos[0][b]);
				Filter[k][b>>5]|=((constantterm1[a][Fpos[0][b]>>5]>>(Fpos[0][b]&0x01f))&0x01)<<(b&0x1f);
				Filter1[k][b>>5]|=((value0[a][Fpos[0][b]>>5]>>(Fpos[0][b]&0x01f))&0x01)<<(b&0x1f);
					//Fpos[Flength]=(b<<4)|k;
					//(k<<(dim-partdim))|b;
				//	Flength++;
			}

			//m=(0x01<<(dim-partdim));
			//a=0;//用以控制轮数
			//for(b=0;b<m;b++)
			//{
			//	weight=0;
			//	l=b;
			//	for(i=0;i<dim;i++)
			//	{
			//		weight+=(l&0x01);
			//		l>>=1;
			//	}
			//	if(weight>dim-7)
			//	{
			//		Filter[k][Flength>>5]|=((constantterm1[a][b>>5]>>(b&0x01f))&0x01)<<(Flength&0x1f);
			//		Filter1[k][Flength>>5]|=((value0[a][b>>5]>>(b&0x01f))&0x01)<<(Flength&0x1f);
			//		//Fpos[Flength]=(b<<4)|k;
			//		Fpos[k][Flength]=(k<<(dim-partdim))|b;
			//		Flength++;
			//	}
			//}
		
		}
		t2=clock();
		printf("%dms\n",t2-t1);
		//下面, 对上面存储的各个部分真值表进行手动Moebius变换
		k=(0x01<<partdim);
		for(i=0;i<partdim;i++)
		{
			Sz=0x01<<i;
			Pos=0;
			while(Pos<k)
			{
				for(b=0;b<Sz;b++)
				{
					for(a=0;a<Flength;a++)
					{
						Filter[Pos+Sz+b][a]=Filter[Pos+Sz+b][a]^Filter[Pos+b][a];
						Filter1[Pos+Sz+b][a]=Filter1[Pos+Sz+b][a]^Filter1[Pos+b][a];
					}

				}
				Pos=Pos+2*Sz;
			}
		}
		for(a=0;a< U64C(0x01)<<(partdim);a++)
		{
			for(k=0;k<Flength;k++)
			{
				Fcheck[a][k]|=Filter[a][k];
				Fcheck1[a][k]|=Filter1[a][k];
			}
		}
		k=0x01<<partdim;
		for(a=0;a<k;a++)
		{
			for(b=0;b<n;b++)
			{
				Filter[a][b]=0;
				Filter1[a][b]=0;
			}
		}
	}

	fprintf(fp2,"*************************\n");
	//dim+=partdim;
	t1=clock();
	n=(0x01<<partdim);
	a=0;
	for(i=0;i<n;i++)
	{
		for(l=0;l<Flength;l++)
		{
			//b=Fpos[l];
			b=l;
			flag = Fcheck[i][b>>5] & ((U64C(0x01))<<(b&0x0000001F));
			flag1 = Fcheck1[i][b>>5] & ((U64C(0x01))<<(b&0x0000001F));
			//flag1=1;
			subdim=0;
			//if((flag==0))//通过线性检测,但是不通过常值检测的
			b=Fpos[i][l];
			if((flag==0)&&(flag1!=0))//通过线性检测,但是不通过常值检测的
			{
				for(j=0;j<dim;j++)
				{
					if(((b>>j)&0x01) ==1)
					{
						fprintf(fp2,"%d,",cube[j]);
						subdim++;
					}
				}
				fprintf(fp2,"\n");
				fprintf(Sdim,"%d,",subdim);
				outputsubcubes(cube,dim,roundnum,a,b,filename);
			}
		}
	}
	/*t2=clock();
	printf("%dms\n",t2-t1);*/
	for(i=0;i<rownum;i++)
	{
		free(constantterm[i]);
		free(constantterm1[i]);
		free(value0[i]);
	}
	free(constantterm);
	free(constantterm1);
	fclose(fp2);
	fclose(Sdim);
		for(i=0;i<16;i++)
	{
		free(Filter[i]);
		free(Filter1[i]);
		free(Fcheck[i]);
		free(Fcheck1[i]);
		free(Fpos[i]);
	}
	free(Filter);
	free(Filter1);
	free(Fcheck);
	free(Fcheck1);
	free(Fpos);
	return cubenum;
}



/////结合二次的特殊形式进行线性检测两者都具有
///K1和K2可以随机选， 只要两种形式的K1+K2，算4次，维数再增加的时候需要复用，但是复用需要更多的存储空间，只需要存储筛选过后的 

//首先是随机选取两组密钥，然后分别计算两种抑或，


///特殊形式线性检测
__host__ u8 specialform_test_randomkey_word(u32 cube[], u32 dim, u32 roundnum,u32 randomkey[][10],u32 twokey[][10],u8 linearity_test_res[])
{
	u32 chosenkey[48+1][10],i,keynum,partialsum[1024]={0},value[48]={0},j;
	//数组长度还有待商榷,需要根据维数重新确定
	//需要传递的参数,随机密钥,cube,roundnum,还需要再申请一块空间用于存放返回的部分求和值,在主机上进行求和,增加一个参数
	u32 **chosenkey_dev,*partialsum_dev;
	u32 blocksPerGrid= 64;//(0x01<<dim)/threadsPerBlock;
	u32 constantterm=0;
	u32 length,check=0,check_con=0;
	u32 *cube_dev,res,check_bit,flag=0;
	//size_t pitch;
	keynum=48;
	length=blocksPerGrid;//((0x01<<dim)>>4)>>8;

	cudaMalloc((void **)&cube_dev,dim*sizeof(u32));
	cudaMalloc((void **)&partialsum_dev,length*sizeof(u32));
	chosenkey_dev=(u32 **)malloc(sizeof(u32 *)*(keynum+1));
	for(i=0;i<keynum+1;i++)
	{
		cudaMalloc((void **) &chosenkey_dev[i],10*sizeof(u32));
		
	}

	for(i=1;i<keynum+1;i+=3)
	{
		/////复制密钥
		for(j=0;j<10;j++)
		{
			chosenkey[i][j]=randomkey[(i/3)*2][j];
			chosenkey[i+1][j]=randomkey[(i/3)*2+1][j];//
			chosenkey[i+2][j]=twokey[i/3][j];
		}
	}

	for(i=0;i<10;i++)
		chosenkey[0][i]=0;
	//将主机端的数据拷贝到设备端
	cudaMemcpy(cube_dev,cube,dim*sizeof(u32),cudaMemcpyHostToDevice);
	for(i=0;i<keynum+1;i++)
	{
		cudaMemcpy(chosenkey_dev[i],chosenkey[i],sizeof(u32)*10,cudaMemcpyHostToDevice);
	}
	cudaEvent_t start,stop;
	cudaEventCreate(&start);  
    cudaEventCreate(&stop);  
    cudaEventRecord(start,0);  
	sum_cube_word<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_dev,roundnum,partialsum_dev,chosenkey_dev[0]);
	cudaMemcpy(partialsum,partialsum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
	cudaEventRecord(stop,0);  
    cudaEventSynchronize(stop);
	float tm;  
    cudaEventElapsedTime(&tm,start,stop);  
    printf("GPU Elapsed time:%.6f ms.\n",tm);  
	for(i=0;i<length;i++)
		constantterm^=partialsum[i];
	for(j=0;j<keynum;j+=3)
	{
		//key1
		sum_cube_word<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_dev,roundnum,partialsum_dev,chosenkey_dev[j+1]);
		cudaMemcpy(partialsum,partialsum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
		for(i=0;i<length;i++)
			value[j]^=partialsum[i];
		//key2
		sum_cube_word<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_dev,roundnum,partialsum_dev,chosenkey_dev[j+2]);
		cudaMemcpy(partialsum,partialsum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
		for(i=0;i<length;i++)
			value[j+1]^=partialsum[i];
		//key1+key2
		sum_cube_word<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_dev,roundnum,partialsum_dev,chosenkey_dev[j+3]);
		cudaMemcpy(partialsum,partialsum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
		for(i=0;i<length;i++)
			value[j+2]^=partialsum[i];
		//
		check_con = check_con| (constantterm^value[j]);
		check = check | (constantterm^value[j]^value[j+1]^value[j+2]);
		if(check == 0xFFFFFFFF)
			break;
	}
	if(check==0xFFFFFFFF)//要改成FFFFFFFF？？？？？
	{
		for(i=0;i<32;i++)
			linearity_test_res[i] = 0;
		/*for(i=0;i<32;i++)
			printf("%d,",linearity_test_res[i]);
		printf("\n");*/
		return 0;
	}
	else{
		res = 2;
		for(i=0;i<32;i++)
		{
			check_bit = (check>>i) & 0x01;
			if(check_bit==0x01)
				linearity_test_res[i]=0;
			else
			{
				flag = 0;
				//检查是否常值
				if((check_con>>i) & 0x01)
					linearity_test_res[i] = 1;
				else
					linearity_test_res[i] = 2;
			}	
		}
	}

	cudaFree(cube_dev);
	cudaFree(partialsum_dev);
	for(i=0;i<keynum+1;i++)
		cudaFree(chosenkey_dev[i]);
	//cudaEvent
	cudaEventDestroy(start);
	cudaEventDestroy(stop);
	return res;
}
// 特殊形式的插值

__host__ void write_superpoly_subcubeSF(FILE * fp,u32 cube[], u8 dim,u32 roundnum, u8 outindex)
{
	u32 chosenkey[80+1][10],i,keynum,partialsum[1024]={0},value[81]={0},j;
	//数组长度还有待商榷,需要根据维数重新确定
	//需要传递的参数,随机密钥,cube,roundnum,还需要再申请一块空间用于存放返回的部分求和值,在主机上进行求和,增加一个参数
	u32 **randkey_dev,*psum_dev,**randkey_dev2;
	u32 blocksPerGrid= 64;//(0x01<<dim)/threadsPerBlock;
	u32 constantterm=0, equnum=80,testnum=32;
	u32 length;
	u32 *cube_d,flag[80]={0},flag1,flag2,flag3,flag4;
	u8 coeff[81]={0},temp2,temp,k;
	//size_t pitch;
	keynum=80;

	length=blocksPerGrid;//((0x01<<dim)>>4)>>8;
	///length=((0x01<<dim);
	cudaMalloc((void **)&cube_d,dim*sizeof(u32));
	cudaMalloc((void **)&psum_dev,length*sizeof(u32));
	randkey_dev=(u32 **)malloc(sizeof(u32 *)*(keynum+1));
	randkey_dev2=(u32 **)malloc(sizeof(u32 *)*(testnum));
	for(i=0;i<keynum+1;i++)
	{
		cudaMalloc((void **) &randkey_dev[i],10*sizeof(u32));
		
	}
	for(i=0;i<testnum;i++)
	{
		cudaMalloc((void **) &randkey_dev2[i],10*sizeof(u32));	
	}
	for(i=1;i<keynum+1;i++)
	{
		for(j=0;j<10;j++)
			chosenkey[i][j]=0;
		//chosenkey[i][(i-1)>>3]=(0x01)<<((i-1)&0x07);
	}
	for(i=0;i<10;i++)
		chosenkey[0][i]=0;
	//将主机端的数据拷贝到设备端
	cudaMemcpy(cube_d,cube,dim*sizeof(u32),cudaMemcpyHostToDevice);
	///拷贝密钥到设备端


	for(i=0;i<equnum;i++)
	{
		cudaMemcpy(randkey_dev[i],chosenkey[i],sizeof(u32)*10,cudaMemcpyHostToDevice);
	}
	//先做2次插值，然后坐线性插值

	for(j=0;j<equnum;j++)
	{
		//printf("START>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n");
		flag1=0;flag2=0;flag3=0;flag4=0;
		sum_cube_word_sf<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_d,roundnum,psum_dev,randkey_dev[j],j,0);
		cudaMemcpy(partialsum,psum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
		for(i=0;i<length;i++)
			flag1^=partialsum[i];
		flag1=(flag1>>outindex)&0x01;

		sum_cube_word_sf<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_d,roundnum,psum_dev,randkey_dev[j],j,1);
		cudaMemcpy(partialsum,psum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
		for(i=0;i<length;i++)
			flag2^=partialsum[i];
		flag2=(flag2>>outindex)&0x01;

		sum_cube_word_sf<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_d,roundnum,psum_dev,randkey_dev[j],j,2);
		cudaMemcpy(partialsum,psum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
		for(i=0;i<length;i++)
			flag3^=partialsum[i];
		flag3=(flag3>>outindex)&0x01;
		
		sum_cube_word_sf<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_d,roundnum,psum_dev,randkey_dev[j],j,3);
		cudaMemcpy(partialsum,psum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
		for(i=0;i<length;i++)
			flag4^=partialsum[i];
		flag4=(flag4>>outindex)&0x01;

		temp=((flag1^flag2^flag3^flag4)>>outindex)&0x01;
	//	printf("DONE>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n");
		if(temp==1)
		{
			//随机密钥，然后拷贝到设备端， 然后
			for(k=0;k<testnum;k++)
				choose_random_key(chosenkey[k]);
			for(k=0;k<testnum;k++)
				cudaMemcpy(randkey_dev2[k],chosenkey[k],sizeof(u32)*10,cudaMemcpyHostToDevice);

			for(k=0;k<testnum;k++)
			{
				flag1=0;flag2=0;flag3=0;flag4=0;
				sum_cube_word_sf<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_d,roundnum,psum_dev,randkey_dev2[k],j,0);
				cudaMemcpy(partialsum,psum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
				for(i=0;i<length;i++)
					flag1^=partialsum[i];
				flag1=(flag1>>outindex)&0x01;

				sum_cube_word_sf<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_d,roundnum,psum_dev,randkey_dev2[k],j,1);
				cudaMemcpy(partialsum,psum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
				for(i=0;i<length;i++)
					flag2^=partialsum[i];
				flag2=(flag2>>outindex)&0x01;

				sum_cube_word_sf<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_d,roundnum,psum_dev,randkey_dev2[k],j,2);
				cudaMemcpy(partialsum,psum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
				for(i=0;i<length;i++)
					flag3^=partialsum[i];
				flag3=(flag3>>outindex)&0x01;

				sum_cube_word_sf<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_d,roundnum,psum_dev,randkey_dev2[k],j,3);
				cudaMemcpy(partialsum,psum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
				for(i=0;i<length;i++)
					flag4^=partialsum[i];
				flag4=(flag4>>outindex)&0x01;

				temp2=((flag1^flag2^flag3^flag4)>>outindex)&0x01;
				if(temp2!=temp)
				{
					break;
				}
			}
			if(k==testnum)//如果是k=keynum,说明这么多次的检测都是通过的,
			{
				fprintf(fp,"x%d*x%d+",j,j+1);
				flag[j]=1;
				flag[j+1]=1;
				//flag[i+2]=1;
				//sig=0;
			}
		}
		
	}

	//可以不需要，直接省略
	for(i=1;i<keynum+1;i++)
	{
		for(j=0;j<10;j++)
			chosenkey[i][j]=0;
		chosenkey[i][(i-1)>>3]=(0x01)<<((i-1)&0x07);
	}

	for(i=0;i<10;i++)
		chosenkey[0][i]=0;

	for(i=0;i<keynum+1;i++)
	{
		cudaMemcpy(randkey_dev[i],chosenkey[i],sizeof(u32)*10,cudaMemcpyHostToDevice);
	}

	cudaEvent_t start,stop;
	cudaEventCreate(&start);  
    cudaEventCreate(&stop);  
    cudaEventRecord(start,0);  
	sum_cube_word<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_d,roundnum,psum_dev,randkey_dev[0]);
	//sum_cube_wordV2<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_d,roundnum,psum_dev,0);
	cudaEventRecord(stop,0);  
    cudaEventSynchronize(stop);  
    float tm;  
    cudaEventElapsedTime(&tm,start,stop);  
    printf("GPU Elapsed time:%.6f ms.\n",tm);  

	cudaMemcpy(partialsum,psum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
	for(i=0;i<length;i++)
		constantterm^=partialsum[i];
	coeff[0]=(constantterm>>outindex)&(0x01);
	
	
	for(j=1;j<keynum+1;j++) 
	{
		if(flag[j]==0)
		{
		sum_cube_word<<<blocksPerGrid,threadsPerBlock>>>(dim,cube_d,roundnum,psum_dev,randkey_dev[j]);
		cudaMemcpy(partialsum,psum_dev,sizeof(u32)*length,cudaMemcpyDeviceToHost);
		for(i=0;i<length;i++)
			value[j]^=partialsum[i];
		coeff[j]=((value[j]>>outindex)&0x01)^coeff[0];
		if(coeff[j]==1)
			fprintf(fp,"x%d+",j-1);
		}	
	}
	fprintf(fp,"%d",coeff[0]);
	 fprintf(fp, "\n");
	//u32 **randkey_dev,*psum_dev;
	 cudaFree(cube_d);
	cudaFree(psum_dev);
	for(i=0;i<keynum+1;i++)
		cudaFree(randkey_dev[i]);
	free(randkey_dev);
	cudaEventDestroy(start);
	cudaEventDestroy(stop);
}

//特殊形式的输出
//void outputcubeofsf(u32 cube[], u8 dim, u32 roundnum, u8 outindex, u32 pos, char filename[],u32 randomkey[][10],u32 twokey[][10])
	void outputcubeofsf(u32 cube[], u8 dim, u32 roundnum, u8 outindex, unsigned __int64 pos, char filename[],u32 randomkey[][10],u32 twokey[][10])
{
	u8 i,j;
	u32 *subcube;
	u8 subdim;
	u8 result=0x00;
	u8 linearity_test_res[32];
	FILE * fp;

	subcube = (u32 *)malloc(dim*sizeof(u32));

	fp = fopen(filename,"a+");
	subdim = 0;
	for (j=0;j<dim;j++) {
		if((pos>>j) & 0x00000001)
		{
			subcube[subdim] = cube[j];
			subdim++;
		}
	}	

	//flag=linearity_test_randomkey_word(subcube, subdim, roundnum,linearity_test_res);
	result=specialform_test_randomkey_word(subcube, subdim, roundnum,randomkey,twokey,linearity_test_res);
	if((linearity_test_res[outindex]==1))
	{
		if(firstoutput)
		{
			fprintf(fp, "\n\nround = %d, dim = %d,",roundnum,dim);
			fprintf(fp, "\nmother cube: ");
			for(i=0;i<dim;i++)
				fprintf(fp, "%d,",cube[i]);
			firstoutput = 0;
		}
		fprintf(fp, "\nround = %d, subdim = %d", roundnum+outindex,subdim);
		fprintf(fp,"\nTYPE2: subcube: ");
		for(j=0;j<subdim;j++)
			fprintf(fp,"%d,",subcube[j]);
		fprintf(fp,"	");
		//write_superpoly_subcube(fp,subcube, subdim,roundnum, outindex);
		//write_superpoly_sfcube(fp,subcube, subdim,roundnum, outindex);
		//write_superpoly_sfcubeV2(fp,subcube, subdim,roundnum, outindex);
		write_superpoly_subcubeSF(fp,subcube, subdim,roundnum, outindex);
	}


	fclose(fp);
	free(subcube);
}

void outputcubeofsf2(u32 cube[], u8 dim, u32 roundnum, u8 outindex, unsigned __int64 pos, char filename[],u32 randomkey[][10],u32 twokey[][10])
{
	u8 i,j;
	u32 *subcube;
	u8 subdim;
	u8 result=0x00;
	u8 linearity_test_res[32];
	FILE * fp;

	subcube = (u32 *)malloc(dim*sizeof(u32));

	fp = fopen(filename,"a+");
	subdim = 0;
	for (j=0;j<dim;j++) {
		if((pos>>j) & 0x00000001)
		{
			subcube[subdim] = cube[j];
			subdim++;
		}
	}	

	//flag=linearity_test_randomkey_word(subcube, subdim, roundnum,linearity_test_res);
	result=specialform_test_randomkey_word(subcube, subdim, roundnum,randomkey,twokey,linearity_test_res);
	if((linearity_test_res[outindex]==1))
	{
		if(firstoutput)
		{
			fprintf(fp, "\n\nround = %d, dim = %d,",roundnum,dim);
			fprintf(fp, "\nmother cube: ");
			for(i=0;i<dim;i++)
				fprintf(fp, "%d,",cube[i]);
			firstoutput = 0;
		}
		fprintf(fp, "\nround = %d, subdim = %d", roundnum+outindex,subdim);
		fprintf(fp,"\nTYPE3: subcube: ");
		for(j=0;j<subdim;j++)
			fprintf(fp,"%d,",subcube[j]);
		fprintf(fp,"	");
		//write_superpoly_subcube(fp,subcube, subdim,roundnum, outindex);
		//write_superpoly_sfcube(fp,subcube, subdim,roundnum, outindex);
		//write_superpoly_sfcubeV2(fp,subcube, subdim,roundnum, outindex);
		write_superpoly_subcubeSF(fp,subcube, subdim,roundnum, outindex);
	}


	fclose(fp);
	free(subcube);
}
//需要注意的是Flength的取值以及dim的截取
u32 linearity_test_dynamicV6(u32 cube[], u32 dim, u32 roundnum,int **canindex, int cannum, char filename[])
{
	unsigned __int64  i,j,a,b,weight,l,m,n,Sz,Pos,tt=0,temp_M=0,k=0;
	u32 key[10],partdim=7;
	u32 **constantterm, **value0, **value1, **value2,**value3,**value4;//常数项2427000
	//u32 **Filter1,**Filter, Flength=2827000, **Fcheck,**Fcheck1, **sFilter1,**sFilter,**sFcheck,**sFcheck1;//3492176
	u32 **Filter1,**Filter, Flength=2427000, **Fcheck,**Fcheck1, **sFilter1,**sFilter,**sFcheck,**sFcheck1,**T2Filter1,**T2Filter,**T2Fcheck,**T2Fcheck1;//3492176
	unsigned __int64 	*Fpos;//用于存储位置
	u32 numrandomkey = 160,tttt;  // 两两一组
	u32 randomkey[256*2][10],sfkey[256*2][10]={0},sfkey2[256][10]={0},tempkey[256][10]={0};//第一组密钥
	u32 randomkeypro[256*2][10]={0},sfkeypro[256*2][10]={0},sfkeypro2[256][10]={0};//第二组密钥
	int keynum=81;
	u8 breakflag=0;
	clock_t t1,t2;
	//u32 **ANF;//还是需要排除常数项
	FILE *fp2,*Sdim;
	partdim=7;
	u32 flag,flag1,subdim,flag2,flag3,flag4,flag5;
	u32 rownum = 1,cubenum=0;
	unsigned __int64  total, total1,total2,total3;
	u32 columnum = U64C(0x01)<<(dim-5-partdim);
	u32 **coeffs;
	int t=0;
	fp2=fopen("CRec.txt","a+");
	Sdim=fopen("subdim.txt","a+");
	n=Flength;
	coeffs=(u32 **)malloc(cannum*sizeof(u32*));
	constantterm = (u32 **)malloc(rownum*sizeof(u32*));
	Filter1=(u32 **) malloc(sizeof(u32*)*128);
	Filter=(u32 **) malloc(sizeof(u32*)*128);//2维数组,用于保存每一个部分函数的ANF(筛选后)
	Fcheck=(u32 **) malloc(sizeof(u32*)*128);
	Fcheck1=(u32 **) malloc(sizeof(u32*)*128);
	//Fpos=(unsigned __int64 **) malloc(sizeof(unsigned __int64  *)*Flength);
	Fpos=(unsigned __int64 *) malloc(sizeof(unsigned __int64 )*(Flength*32));//用于保存筛选出来的点的索引, 不需要乘以32

	sFilter1=(u32 **) malloc(sizeof(u32*)*128);//乘以128即可？？
	sFilter=(u32 **) malloc(sizeof(u32*)*128);//2维数组,用于保存每一个部分函数的ANF(筛选后)
	sFcheck=(u32 **) malloc(sizeof(u32*)*128);
	sFcheck1=(u32 **) malloc(sizeof(u32*)*128);

	T2Filter1=(u32 **) malloc(sizeof(u32*)*128);
	T2Filter=(u32 **) malloc(sizeof(u32*)*128);//2维数组,用于保存每一个部分函数的ANF(筛选后)
	T2Fcheck=(u32 **) malloc(sizeof(u32*)*128);
	T2Fcheck1=(u32 **) malloc(sizeof(u32*)*128);
	for(i=0;i<rownum;i++)
		constantterm[i]=(u32*)malloc(columnum*sizeof(u32));

	for(i=0;i<cannum;i++)
		coeffs[i]=(u32 *)malloc(sizeof(u32)*81);

	for(i=0;i<128;i++)
	{
		Filter1[i]=(u32*)malloc(Flength*sizeof(u32));
		Filter[i]=(u32*)malloc(Flength*sizeof(u32));
		//Fpos[i]=(unsigned __int64 *)malloc(Flength*sizeof(unsigned __int64));//首先，Fpos只需要存储一次，
		Fcheck[i]=(u32*)malloc(Flength*sizeof(u32));
		Fcheck1[i]=(u32*)malloc(Flength*sizeof(u32));

		sFilter1[i]=(u32*)malloc(Flength*sizeof(u32));
		sFilter[i]=(u32*)malloc(Flength*sizeof(u32));
		sFcheck[i]=(u32*)malloc(Flength*sizeof(u32));
		sFcheck1[i]=(u32*)malloc(Flength*sizeof(u32));

		T2Filter1[i]=(u32*)malloc(Flength*sizeof(u32));
		T2Filter[i]=(u32*)malloc(Flength*sizeof(u32));
		T2Fcheck[i]=(u32*)malloc(Flength*sizeof(u32));
		T2Fcheck1[i]=(u32*)malloc(Flength*sizeof(u32));
	}
	
	value0 = (u32 **)malloc(rownum*sizeof(u32*));
	value1 = (u32 **)malloc(rownum*sizeof(u32*));
	value2 = (u32 **)malloc(rownum*sizeof(u32*));
	value3 = (u32 **)malloc(rownum*sizeof(u32*));
	value4 = (u32 **)malloc(rownum*sizeof(u32*));
	for(i=0;i<rownum;i++)
	{
		value0[i]=(u32*)malloc(columnum*sizeof(u32));
		value1[i]=(u32*)malloc(columnum*sizeof(u32));
		value2[i]=(u32*)malloc(columnum*sizeof(u32));
		value3[i]=(u32*)malloc(columnum*sizeof(u32));
		value4[i]=(u32*)malloc(columnum*sizeof(u32));
	}


	//在这里加一个循环
	partdim=7;
	//partdim=7;
	
	//增加一组随机密钥
	srand((unsigned int) time(NULL));
	//for(i=0;i<numrandomkey;i++)
		//choose_random_key(randomkey[i]);//GenRandomKeyV3Right(randomkey,sfkey2);
	//genrandomkeyV2(randomkey,sfkey);//生成另外一组随机密钥, 太慢,00.06

	for(i=1;i<keynum;i++)
	{
		for(j=0;j<10;j++)
			randomkey[i][j]=0;
		randomkey[i][(i-1)>>3]=(0x01)<<((i-1)&0x07);
	}
	
	for(a=0;a<128;a++)
		for(b=0;b<Flength;b++)
		{
			Filter[a][b]=0;
			Filter1[a][b]=0;
			Fpos[b]=0;
			Fcheck[a][b]=0;
			Fcheck1[a][b]=0;

			sFilter[a][b]=0;
			sFilter1[a][b]=0;
			sFcheck[a][b]=0;
			sFcheck1[a][b]=0;

			T2Filter[a][b]=0;
			T2Filter1[a][b]=0;
			T2Fcheck[a][b]=0;
			T2Fcheck1[a][b]=0;
		}
	//可能需要换更好的组合数生成器，暂时不需要
	Flength=0;
	m=U64C(0x01)<<(dim-partdim);
	printf("Start get index>>>>\n");
	for(b=0;b<m;b++)
	{
		weight=0;
		l=b;
		for(i=0;i<dim;i++)
		{
			weight+=(l&0x01);
			l>>=1;
		}
		if(weight>(dim-partdim-9))//41-7-10+1=25+7=32//cong32kaishi
		//if(weight>21)//42-9+1//直接写成数字，然后再验证一下是否正确
		{
			Fpos[Flength]= (U64C(0x00)<<(dim-partdim))|b;
			Flength++;
		}
	}
		//总共需要Flength个点，每次求完一个子函数的真值表以后，筛取相应位置的0或1放入到Filter里，然后对Filter进行Moebius变换
	printf("Done>>>>\nStart  Computing Cube>>>>\n");
	printf("%u\n",Flength);
	printf("%llu\n",Fpos[Flength-1]);
	printf("%llu\n",Fpos[Flength-2]);
	printf("%llu\n",Fpos[Flength-3]);
	//system("pause");
	//for(j=0;j<numrandomkey;j=j+2)
	breakflag=0;
	for(j=0;j<keynum+1;j++)
	{
		//Flength=0;
			t1=clock();
		for(k=0;k<128;k++)
		{
			for(a=0;a<rownum;a++)
				for(b=0;b<columnum;b++)
				{
						constantterm[a][b] = 0;
						value0[a][b] = 0;
						value1[a][b] = 0;
						value2[a][b] = 0;
						value3[a][b] = 0;
						value4[a][b] = 0;
				}
			for(i=0;i<10;i++)
				key[i]= 0;
			construc_truth_table_dynamic_CutM_32(cube, dim, roundnum,constantterm,rownum,columnum,key,k);//常值f(0)
		
			if(j>0)
			{
				for(i=0;i<10;i++)
						key[i] = randomkey[j][i];
				construc_truth_table_dynamic_CutM_32(cube, dim, roundnum,value0,rownum,columnum,key,k);//key1
			}
			for(a=0;a<rownum;a++)
			{
				//当j=0时, 不需要异或
				if(j>0)
				{
					for(b=0;b<columnum;b++)
					{
						constantterm[a][b]= constantterm[a][b]^value0[a][b];//常值1
					}
				}
				temp_M=(U64C(0x01)<<(dim-partdim));
				Moebius(constantterm[a], temp_M);
			}
			a=0;
			for(b=0;b<Flength;b++)
			{
				Filter1[k][b>>5]|=((constantterm[a][Fpos[b]>>5]>>(Fpos[b]&0x01f))&0x01)<<(b&0x1f);
			}
		}
		t2=clock();
			printf("%d  %dms\n",j,t2-t1);
		//下面, 对上面存储的各个部分真值表进行手动Moebius变换
		k=(0x01<<partdim);
		if(Flength%32==0)
			tt=Flength/32;
		else
			tt=Flength/32+1;
		//只有这一部分可能会有问题
		for(i=0;i<partdim;i++)
		{
			Sz=0x01L<<i;
			Pos=0;
			while(Pos<k)
			{
				for(b=0;b<Sz;b++)
				{
					//for(a=0;a<Flength/32+1;a++)
					for(a=0;a<tt;a++)
					{
						Filter1[Pos+Sz+b][a]=Filter1[Pos+Sz+b][a]^Filter1[Pos+b][a];
					}
				}
				Pos=Pos+2*Sz;
			}
		}
		//对于每一个候选的立方变远集, 计算x_i的系数
		for(t=0;t<cannum;t++)
		{
			i=canindex[t][0];
			b=canindex[t][1];
			coeffs[t][j]=(Filter1[i][b>>5] >>(b&0x0000001F))&0x01;
		}
		k=0x01<<partdim;
		for(a=0;a<k;a++)
		{
			for(b=0;b<(Flength/32)+1;b++)
			{
				Filter1[a][b]=0;
			}
		}
	}
	Sleep(01);
	fprintf(fp2,"*************************\n");
	//dim+=partdim;
	n=(0x01<<partdim);
	a=0;

	//system("pause");
	n=(0x01<<partdim);
	a=0;
	//将超多项式写到文件中
	FILE *fpout;
	fpout=fopen(filename,"a+");
	fprintf(fpout, "Mother cube :");

	for(i=0;i<dim;i++)
	{
		fprintf(fpout, "%d,", cube[i]);
	}
	fprintf(fpout,"\n");

	for(t=0;t<cannum;t++)
	{
		printf("Testing %d-th cube",t);
		i=canindex[t][0];
		l=canindex[t][1];
		{
			//b=Fpos[l];
			b=l;
			//flag1=1;
			subdim=0;
			b= (i<<(dim-partdim))|(Fpos[b]);//移位没有问题
			
			if(1)
			{
				for(j=0;j<dim;j++)
				{
					if(((b>>j)&0x01) ==1)
					{
						fprintf(fp2,"%d,",cube[j]);
						printf("%d,",cube[j]);
						subdim++;
					}
				}
				printf("\n");
				fprintf(fp2,"\n");
				fprintf(Sdim,"%d,",subdim);
				printf("%d ,%d,%d\n",1,i,subdim);
				fprintf(fpout,"subcube: ");
				for(j=0;j<dim;j++)
				{
					if(((b>>j)&0x01) ==1)
					{
						fprintf(fpout,"%d,",cube[j]);
					}
				}
				fprintf(fpout,"\nsubdim=%d     ", subdim);
				fprintf(fpout,"superpoly: ", subdim);
				if(coeffs[t][0]==1)
					fprintf(fpout,"1");
				else
					fprintf(fpout,"0");
				for(j=1;j<81;j++)
				{
					if(coeffs[t][j]==1)
						fprintf(fpout,"+x%d", j-1);
				}
				fprintf(fpout,"\n\n");
			}
		}
	}

	//Sleep(7200000);
	//////38-42
	//for(i=0;i<0;i++)
	
	for(i=0;i<rownum;i++)
	{
		free(constantterm[i]);
		free(value0[i]);
		free(value1[i]);
		free(value2[i]);
		free(value3[i]);
		free(value4[i]);
	}
	free(constantterm);
	free(value0);
	free(value1);
	free(value2);
	free(value3);
	free(value4);
	for(i=0;i<128;i++)
	{
		free(Filter[i]);
		free(Filter1[i]);
		free(sFilter[i]);
		free(sFilter1[i]);
		free(Fcheck[i]);
		free(Fcheck1[i]);
		free(sFcheck[i]);
		free(sFcheck1[i]);
		free(T2Filter[i]);
		free(T2Filter1[i]);
		free(T2Fcheck[i]);
		free(T2Fcheck1[i]);
		//free(Fpos[i]);
	}
	free(Filter);
	free(Filter1);
	free(sFilter);
	free(sFilter1);
	free(Fcheck);
	free(Fcheck1);
	free(sFcheck);
	free(sFcheck1);
	free(T2Fcheck);
	free(T2Fcheck1);
	free(T2Filter);
	free(T2Filter1);
	free(Fpos);
	fclose(fp2);
	fclose(Sdim);
	fclose(fpout);
	return cubenum;
}
void choose_cube(u8 dim, u32 cube[], u8 startindex)
{
   u8 i=0;
   u8 j=0;
   u8 random_number_tab[256] = {41,20,63,67,10,29,66,32,56,27,56,17,10,44,13,32,50,42,37,67,52,35,71,25,40,59,\
25,48,35,79,17,71,63,31,0,79,7,79,38,9,78,19,54,58,0,71,43,37,11,34,32,67,27,\
49,67,19,25,27,62,33,14,20,61,76,7,43,52,20,26,11,26,78,23,79,7,11,24,63,29,12,\
5,50,37,54,66,17,56,65,22,75,15,67,9,43,6,60,27,74,14,10,65,77,58,23,58,38,47,0,\
77,42,30,69,18,43,35,71,69,3,6,4,9,14,5,7,55,26,64,18,27,9,38,4,0,0,57,69,2,65,\
34,21,49,7,2,35,66,25,35,51,79,61,66,41,29,72,52,79,4,62,22,8,15,41,7,62,68,22,38,\
75,20,37,32,5,64,31,71,20,36,63,35,56,34,31,40,71,57,43,15,12,17,70,16,50,26,71,48,\
31,65,77,9,68,79,25,15,0,68,52,7,72,55,77,73,18,46,76,1,41,9,40,49,20,8,77,49,6,72,\
79,30,28,17,54,76,39,67,61,36,32,49,43,79,31,46,70,34,37,33,77,45,5,33,15,11,17,\
74,47,51,45};
      //srand((unsigned int)(time));
   srand((unsigned int)(time(NULL)));
   if(startindex==0)
   {
		cube[i]=random_number_tab[rand()&0xFF];
		startindex = 1;
   }

 for(i=startindex;i<dim;i++)
   {
	cube[i]=random_number_tab[rand()&0xFF];
LOOP: for (j=0;j<i;j++)
	  {
		if (cube[i]==cube[j]) 
		{
         cube[i]=random_number_tab[rand()&0xFF];
		 goto LOOP;
		}
	  }
   }
}




void search_cube_parallel(u32 cube[], u8 dim, u32 roundnum, u8 startindex, u32 totalnum, char filename[])
{
	u32 k,j=0;
	FILE *fp;
	for(k=0;k<totalnum;k++){ printf("%d,",k);
		choose_cube(dim, cube, startindex);
			 //打印cube
			 printf("\n");
			 for(j=0;j<dim;j++)
				 printf("%d,",cube[j]);
		firstoutput  = 1;
		fp=fopen(filename,"a+");
		fprintf(fp,"chosen cube %d: ",k);
		for(j=0;j<dim;j++)
		{
			fprintf(fp,"%d,",cube[j]);
		}
		fprintf(fp,"\n");
		fclose(fp);
		//linearity_test_dynamicV6(cube, dim, roundnum,filename);
	}
}


u32 linearity_test_dynamicVV(u32 cube[], u32 dim, u32 roundnum,u32 randomkey[][10],u32 sfkey[][10], u32 sfkey2[][10], u32 randomkeypro[][10], u32 sfkeypro[][10], u32 sfkeypro2[][10],char filename[])
{
	unsigned __int64  i,j,a,b,weight,l,m,n,Sz,Pos,tt=0,temp_M=0,k=0;
	u32 key[10],partdim=7;
	u32 **constantterm, **value0, **value1, **value2,**value3,**value4;//常数项2427000
	//u32 **Filter1,**Filter, Flength=2827000, **Fcheck,**Fcheck1, **sFilter1,**sFilter,**sFcheck,**sFcheck1;//3492176
	u32 **Filter1,**Filter, Flength=2427000, **Fcheck,**Fcheck1, **sFilter1,**sFilter,**sFcheck,**sFcheck1,**T2Filter1,**T2Filter,**T2Fcheck,**T2Fcheck1;//3492176
	unsigned __int64 	*Fpos;//用于存储位置
	u32 numrandomkey = 64;  // 两两一组
	//u32 randomkey[32*2][10],sfkey[16*2][10]={0},sfkey2[32][10]={0},tempkey[32][10]={0};//第一组密钥
	//u32 randomkeypro[64][10]={0},sfkeypro[16*2][10]={0},sfkeypro2[32][10]={0};//第二组密钥
	u8 breakflag=0;
	clock_t t1,t2;
	//u32 **ANF;//还是需要排除常数项
	FILE *fp2,*Sdim;
	partdim=7;
	u32 flag,flag1,subdim,flag2,flag3,flag4,flag5;
	u32 rownum = 1,cubenum=0;
	unsigned __int64  total, total1,total2,total3;
	u32 columnum = U64C(0x01)<<(dim-5-partdim);
	fp2=fopen("CRec.txt","a+");
	Sdim=fopen("subdim.txt","a+");
	n=Flength;
	constantterm = (u32 **)malloc(rownum*sizeof(u32*));
	Filter1=(u32 **) malloc(sizeof(u32*)*128);
	Filter=(u32 **) malloc(sizeof(u32*)*128);//2维数组,用于保存每一个部分函数的ANF(筛选后)
	Fcheck=(u32 **) malloc(sizeof(u32*)*128);
	Fcheck1=(u32 **) malloc(sizeof(u32*)*128);
	//Fpos=(unsigned __int64 **) malloc(sizeof(unsigned __int64  *)*Flength);
	Fpos=(unsigned __int64 *) malloc(sizeof(unsigned __int64 )*(Flength*32));//用于保存筛选出来的点的索引, 不需要乘以32

	sFilter1=(u32 **) malloc(sizeof(u32*)*128);//乘以128即可？？
	sFilter=(u32 **) malloc(sizeof(u32*)*128);//2维数组,用于保存每一个部分函数的ANF(筛选后)
	sFcheck=(u32 **) malloc(sizeof(u32*)*128);
	sFcheck1=(u32 **) malloc(sizeof(u32*)*128);

	T2Filter1=(u32 **) malloc(sizeof(u32*)*128);
	T2Filter=(u32 **) malloc(sizeof(u32*)*128);//2维数组,用于保存每一个部分函数的ANF(筛选后)
	T2Fcheck=(u32 **) malloc(sizeof(u32*)*128);
	T2Fcheck1=(u32 **) malloc(sizeof(u32*)*128);
	for(i=0;i<rownum;i++)
		constantterm[i]=(u32*)malloc(columnum*sizeof(u32));

	for(i=0;i<128;i++)
	{
		Filter1[i]=(u32*)malloc(Flength*sizeof(u32));
		Filter[i]=(u32*)malloc(Flength*sizeof(u32));
		//Fpos[i]=(unsigned __int64 *)malloc(Flength*sizeof(unsigned __int64));//首先，Fpos只需要存储一次，
		Fcheck[i]=(u32*)malloc(Flength*sizeof(u32));
		Fcheck1[i]=(u32*)malloc(Flength*sizeof(u32));

		sFilter1[i]=(u32*)malloc(Flength*sizeof(u32));
		sFilter[i]=(u32*)malloc(Flength*sizeof(u32));
		sFcheck[i]=(u32*)malloc(Flength*sizeof(u32));
		sFcheck1[i]=(u32*)malloc(Flength*sizeof(u32));

		T2Filter1[i]=(u32*)malloc(Flength*sizeof(u32));
		T2Filter[i]=(u32*)malloc(Flength*sizeof(u32));
		T2Fcheck[i]=(u32*)malloc(Flength*sizeof(u32));
		T2Fcheck1[i]=(u32*)malloc(Flength*sizeof(u32));
	}
	
	value0 = (u32 **)malloc(rownum*sizeof(u32*));
	value1 = (u32 **)malloc(rownum*sizeof(u32*));
	value2 = (u32 **)malloc(rownum*sizeof(u32*));
	value3 = (u32 **)malloc(rownum*sizeof(u32*));
	value4 = (u32 **)malloc(rownum*sizeof(u32*));
	for(i=0;i<rownum;i++)
	{
		value0[i]=(u32*)malloc(columnum*sizeof(u32));
		value1[i]=(u32*)malloc(columnum*sizeof(u32));
		value2[i]=(u32*)malloc(columnum*sizeof(u32));
		value3[i]=(u32*)malloc(columnum*sizeof(u32));
		value4[i]=(u32*)malloc(columnum*sizeof(u32));
	}


	//在这里加一个循环
	partdim=7;
	//partdim=7;
	
	//增加一组随机密钥
	//srand((unsigned int) time(NULL));
	//for(i=0;i<numrandomkey;i++)
	//	choose_random_key(randomkey[i]);//GenRandomKeyV3Right(randomkey,sfkey2);
	////genrandomkeyV2(randomkey,sfkey);//生成另外一组随机密钥, 太慢,00.06
	//genrandomkeyV2Right(randomkey,sfkey);
	//printf("\n%d\n",randomkey[63][0]);
	//printf("%d\n",sfkey[31][0]);
	//printf("RandomKey1  DONE >>>>\n");
	//GenRandomKeyV3Right(randomkey,sfkey2);
	//printf("%d\n",sfkey2[31][0]);
	//printf("RandomKey2  DONE >>>>\n");
	////dim-=partdim;
	//genrandomkeyV2Right(randomkeypro,sfkeypro);
	//GenRandomKeyV3Right(randomkeypro,sfkeypro2);
	for(a=0;a<128;a++)
		for(b=0;b<Flength;b++)
		{
			Filter[a][b]=0;
			Filter1[a][b]=0;
			Fpos[b]=0;
			Fcheck[a][b]=0;
			Fcheck1[a][b]=0;

			sFilter[a][b]=0;
			sFilter1[a][b]=0;
			sFcheck[a][b]=0;
			sFcheck1[a][b]=0;

			T2Filter[a][b]=0;
			T2Filter1[a][b]=0;
			T2Fcheck[a][b]=0;
			T2Fcheck1[a][b]=0;
		}
	//可能需要换更好的组合数生成器，暂时不需要
	Flength=0;
	m=U64C(0x01)<<(dim-partdim);
	printf("Start get index>>>>\n");
	for(b=0;b<m;b++)
	{
		weight=0;
		l=b;
		for(i=0;i<dim;i++)
		{
			weight+=(l&0x01);
			l>>=1;
		}
		if(weight>(dim-partdim-9))//41-7-10+1=25+7=32//cong32kaishi
		//if(weight>21)//42-9+1//直接写成数字，然后再验证一下是否正确
		{
			Fpos[Flength]= (U64C(0x00)<<(dim-partdim))|b;
			Flength++;
		}
	}
		//总共需要Flength个点，每次求完一个子函数的真值表以后，筛取相应位置的0或1放入到Filter里，然后对Filter进行Moebius变换
	printf("Done>>>>\nStart  Computing Cube>>>>\n");
	printf("%u\n",Flength);
	printf("%llu\n",Fpos[Flength-1]);
	printf("%llu\n",Fpos[Flength-2]);
	printf("%llu\n",Fpos[Flength-3]);
	//system("pause");
	//for(j=0;j<numrandomkey;j=j+2)
	breakflag=0;
	for(j=0;j<10;j=j+2)
	{
		//Flength=0;
			t1=clock();
		for(k=0;k<128;k++)
		{
		//	Flength=0;
		//
			for(a=0;a<rownum;a++)
				for(b=0;b<columnum;b++)
				{
						constantterm[a][b] = 0;
						value0[a][b] = 0;
						value1[a][b] = 0;
						value2[a][b] = 0;
						value3[a][b] = 0;
						value4[a][b] = 0;
				}
			//取cube,然后计算常值
		for(i=0;i<10;i++)
			key[i]= 0;
		construc_truth_table_dynamic_CutM_32(cube, dim, roundnum,constantterm,rownum,columnum,key,k);//常值f(0)
			
		for(i=0;i<10;i++)
				key[i] = randomkey[j][i];
		construc_truth_table_dynamic_CutM_32(cube, dim, roundnum,value0,rownum,columnum,key,k);//key1

		for(i=0;i<10;i++)
				key[i]=randomkey[j+1][i];
		construc_truth_table_dynamic_CutM_32(cube, dim, roundnum,value3,rownum,columnum,key,k);//key2，constantterm1-〉value1， value0实际上f(key1)+f(key2)
			
		for(i=0;i<10;i++)
				key[i]=randomkey[j][i]^randomkey[j+1][i];
		construc_truth_table_dynamic_CutM_32(cube, dim, roundnum,value1,rownum,columnum,key,k);//key1^key2 f(key1+key2)


		//增加
		//for(i=0;i<10;i++)
				//key[i]=sfkey[j/2][i];//可能有问题
		//construc_truth_table_dynamic_CutM_32(cube, dim, roundnum,value2,rownum,columnum,key,k);//f(key1'+key2')


		for(i=0;i<10;i++)
				key[i]=sfkey2[j/2][i];//可能有问题
		construc_truth_table_dynamic_CutM_32(cube, dim, roundnum,value4,rownum,columnum,key,k);//f(key1''+key2'')

			for(a=0;a<rownum;a++){
				for(b=0;b<columnum;b++)
				{
					value1[a][b] = constantterm[a][b]^value1[a][b]^value0[a][b]^value3[a][b];//线性形式1
					//value2[a][b] = constantterm[a][b]^value2[a][b]^value0[a][b]^value3[a][b];//线性检测-形式2
					//value4[a][b] = constantterm[a][b]^value4[a][b]^value0[a][b]^value3[a][b];//newtype2
					value0[a][b]= constantterm[a][b]^value0[a][b];//常值1
					//constantterm[a][b]= constantterm[a][b]^value0[a][b];//常值2
				}
				temp_M=(U64C(0x01)<<(dim-partdim));
				Moebius(value1[a], temp_M);
				//Moebius(value2[a], temp_M);
				//Moebius(value0[a], temp_M);
				Moebius(value4[a], temp_M);
				Moebius(constantterm[a], temp_M);
			 }
			a=0;
			for(b=0;b<Flength;b++)
			{
				Filter[k][b>>5]|=((value1[a][Fpos[b]>>5]>>(Fpos[b]&0x01f))&0x01)<<(b&0x1f);//每一个单项式的系数占据一个比特，然后存下所有的
				Filter1[k][b>>5]|=((value0[a][Fpos[b]>>5]>>(Fpos[b]&0x01f))&0x01)<<(b&0x1f);
				//
				sFilter[k][b>>5]|=((value2[a][Fpos[b]>>5]>>(Fpos[b]&0x01f))&0x01)<<(b&0x1f);
				sFilter1[k][b>>5]|=((constantterm[a][Fpos[b]>>5]>>(Fpos[b]&0x01f))&0x01)<<(b&0x1f);
				//newtype
				T2Filter[k][b>>5]|=((value4[a][Fpos[b]>>5]>>(Fpos[b]&0x01f))&0x01)<<(b&0x1f);
				T2Filter1[k][b>>5]|=((value0[a][Fpos[b]>>5]>>(Fpos[b]&0x01f))&0x01)<<(b&0x1f);
				//Fpos[Flength]=(b<<4)|k;
				//(k<<(dim-partdim))|b;
				//	Flength++;
			}
		}
		t2=clock();
			printf("%d  %dms\n",j,t2-t1);
		//下面, 对上面存储的各个部分真值表进行手动Moebius变换
		k=(0x01<<partdim);
		if(Flength%32==0)
			tt=Flength/32;
		else
			tt=Flength/32+1;
		//只有这一部分可能会有问题
		for(i=0;i<partdim;i++)
		{
			Sz=0x01L<<i;
			Pos=0;
			while(Pos<k)
			{
				for(b=0;b<Sz;b++)
				{
					//for(a=0;a<Flength/32+1;a++)
					for(a=0;a<tt;a++)
					{
						Filter[Pos+Sz+b][a]=Filter[Pos+Sz+b][a]^Filter[Pos+b][a];//只要位置是相互对应的就可以，等会找一个试一下
						Filter1[Pos+Sz+b][a]=Filter1[Pos+Sz+b][a]^Filter1[Pos+b][a];
						//
						//
						sFilter[Pos+Sz+b][a]=sFilter[Pos+Sz+b][a]^sFilter[Pos+b][a];
						sFilter1[Pos+Sz+b][a]=sFilter1[Pos+Sz+b][a]^sFilter1[Pos+b][a];
						//
						//
						T2Filter[Pos+Sz+b][a]=T2Filter[Pos+Sz+b][a]^T2Filter[Pos+b][a];
						T2Filter1[Pos+Sz+b][a]=T2Filter1[Pos+Sz+b][a]^T2Filter1[Pos+b][a];
					}
				}
				Pos=Pos+2*Sz;
			}
		}
		if(Flength%32==0)
			tt=Flength/32;
		else
			tt=Flength/32+1;
		for(a=0;a< U64C(0x01)<<(partdim);a++)
		{
			for(k=0;k<tt;k++)
			{
				Fcheck[a][k]|=Filter[a][k];
				Fcheck1[a][k]|=Filter1[a][k];

				sFcheck[a][k]|=sFilter[a][k];
				sFcheck1[a][k]|=sFilter1[a][k];

				T2Fcheck[a][k]|=T2Filter[a][k];
				T2Fcheck1[a][k]|=T2Filter1[a][k];
			}
		}
		k=0x01<<partdim;
		for(a=0;a<k;a++)
		{
			for(b=0;b<(Flength/32)+1;b++)
			{
				Filter[a][b]=0;
				Filter1[a][b]=0;
				sFilter[a][b]=0;
				sFilter1[a][b]=0;
				T2Filter[a][b]=0;
				T2Filter1[a][b]=0;
			}
		}
		if((j%16==0)&&(j>0))
			Sleep(01);
	}
	Sleep(01);
	fprintf(fp2,"*************************\n");
	//dim+=partdim;
	n=(0x01<<partdim);
	a=0;
	for(i=0;i<n;i++)//正确
	{
		printf("%d,",i);
		for(l=0;l<Flength;l++)
		{
			//b=Fpos[l];
			b=l;
			flag = Fcheck[i][b>>5] & ((U64C(0x01))<<(b&0x0000001F));
			flag1 = Fcheck1[i][b>>5] & ((U64C(0x01))<<(b&0x0000001F));

			flag2= sFcheck[i][b>>5] & ((U64C(0x01))<<(b&0x0000001F));// (sFcheck[i][b>>5]>>(b&0x0000001F))&0x01;// & ((U64C(0x01))<<(b&0x0000001F));
			flag3= Fcheck1[i][b>>5] & ((U64C(0x01))<<(b&0x0000001F));//(sFcheck1[i][b>>5]>>(b&0x0000001F))&0x01;

			flag4= T2Fcheck[i][b>>5] & ((U64C(0x01))<<(b&0x0000001F));// (sFcheck[i][b>>5]>>(b&0x0000001F))&0x01;// & ((U64C(0x01))<<(b&0x0000001F));
			flag5= Fcheck1[i][b>>5] & ((U64C(0x01))<<(b&0x0000001F));//(sFcheck1[i][b>>5]>>(b&0x0000001F))&0x01;
			//flag1=1;
			subdim=0;
			b= (i<<(dim-partdim))|(Fpos[b]);//移位没有问题
			if(((flag==0)&&(flag1!=0)))
			{
				fprintf(fp2,"****Type1*****");
				printf("****Type1*****");
				for(j=0;j<dim;j++)
				{
					if(((b>>j)&0x01) ==1)
					{
						fprintf(fp2,"%d,",cube[j]);
						printf("%d,",cube[j]);
						subdim++;
					}
				}
				printf("\n");
				fprintf(fp2,"\n");
				fprintf(Sdim,"%d,",subdim);
				//printf("%d ,%d,%d\n",1,i,subdim);
				//outputsubcubes(cube,dim,roundnum,a,b,filename);
			}
			///
			subdim=0;
			//if(((flag2==0)&&(flag3!=0)))
			if(0)
			{
				fprintf(fp2,"****Type2*****");
				printf("****Type2*****");
				for(j=0;j<dim;j++)
				{
					if(((b>>j)&0x01) ==1)
					{
						fprintf(fp2,"%d,",cube[j]);
						printf("%d,",cube[j]);
						subdim++;
					}
				}
				printf("\n");
				fprintf(fp2,"\n");
				//printf("%d,%d,%d\n",2,i,subdim);

				//genrandomkeyV2Right(randomkey,sfkey);
				//outputcubeofsf(cube,dim,roundnum,a,b,filename,randomkeypro,sfkeypro);
			}

			subdim=0;
			//if(((flag4==0)&&(flag5!=0)))
			if(0)
			{
				fprintf(fp2,"****Type3*****");
				printf("****Type3*****");
				for(j=0;j<dim;j++)
				{
					if(((b>>j)&0x01) ==1)
					{
						fprintf(fp2,"%d,",cube[j]);
						printf("%d,",cube[j]);
						subdim++;
					}
				}
				printf("\n");
				fprintf(fp2,"\n");
				//printf("%d,%d,%d\n",3,i,subdim);

				//srand((unsigned int) time(NULL));
				/*for(i=0;i<numrandomkey;i++)
					choose_random_key(randomkey[i]);
				GenRandomKeyV3Right(randomkey,sfkey2);*/
				//outputcubeofsf2(cube,dim,roundnum,a,b,filename,randomkeypro,sfkeypro2);
			}
		}
	}
	printf("\nDone1>>>>\n");
	//system("pause");
	n=(0x01<<partdim);
	a=0;
	for(i=0;i<n;i++)//正确
	{
		printf("%d,",i);
		for(l=0;l<Flength;l++)
		{
			//b=Fpos[l];
			b=l;
			flag = Fcheck[i][b>>5] & ((U64C(0x01))<<(b&0x0000001F));
			flag1 = Fcheck1[i][b>>5] & ((U64C(0x01))<<(b&0x0000001F));

			flag2= sFcheck[i][b>>5] & ((U64C(0x01))<<(b&0x0000001F));// (sFcheck[i][b>>5]>>(b&0x0000001F))&0x01;// & ((U64C(0x01))<<(b&0x0000001F));
			flag3= Fcheck1[i][b>>5] & ((U64C(0x01))<<(b&0x0000001F));//(sFcheck1[i][b>>5]>>(b&0x0000001F))&0x01;

			flag4= T2Fcheck[i][b>>5] & ((U64C(0x01))<<(b&0x0000001F));// (sFcheck[i][b>>5]>>(b&0x0000001F))&0x01;// & ((U64C(0x01))<<(b&0x0000001F));
			flag5= Fcheck1[i][b>>5] & ((U64C(0x01))<<(b&0x0000001F));//(sFcheck1[i][b>>5]>>(b&0x0000001F))&0x01;
			//flag1=1;
			subdim=0;
			b= (i<<(dim-partdim))|(Fpos[b]);//移位没有问题
			if(((flag==0)&&(flag1!=0)))
			{
				for(j=0;j<dim;j++)
				{
					if(((b>>j)&0x01) ==1)
					{
						fprintf(fp2,"%d,",cube[j]);
						printf("%d,",cube[j]);
						subdim++;
					}
				}
				printf("\n");
				fprintf(fp2,"\n");
				fprintf(Sdim,"%d,",subdim);
				printf("%d ,%d,%d\n",1,i,subdim);
				outputsubcubes(cube,dim,roundnum,a,b,filename);
			}
			///
			subdim=0;
			if(((flag2==0)&&(flag3!=0)))
			{
				fprintf(fp2,"****Type2*****");
				printf("****Type2*****");
				for(j=0;j<dim;j++)
				{
					if(((b>>j)&0x01) ==1)
					{
						fprintf(fp2,"%d,",cube[j]);
						printf("%d,",cube[j]);
						subdim++;
					}
				}
				printf("\n");
				fprintf(fp2,"\n");
				printf("%d,%d,%d\n",2,i,subdim);

				//genrandomkeyV2Right(randomkey,sfkey);
				outputcubeofsf(cube,dim,roundnum,a,b,filename,randomkeypro,sfkeypro);
			}

			subdim=0;
			if(((flag4==0)&&(flag5!=0)))
			{
				fprintf(fp2,"****Type3*****");
				printf("****Type3*****");
				for(j=0;j<dim;j++)
				{
					if(((b>>j)&0x01) ==1)
					{
						fprintf(fp2,"%d,",cube[j]);
						printf("%d,",cube[j]);
						subdim++;
					}
				}
				printf("\n");
				fprintf(fp2,"\n");
				printf("%d,%d,%d\n",3,i,subdim);

				srand((unsigned int) time(NULL));
				/*for(i=0;i<numrandomkey;i++)
					choose_random_key(randomkey[i]);
				GenRandomKeyV3Right(randomkey,sfkey2);*/
				outputcubeofsf2(cube,dim,roundnum,a,b,filename,randomkeypro,sfkeypro2);
			}
		}
	}
	//Sleep(7200000);
	//////38-42
	//for(i=0;i<0;i++)

	for(i=0;i<rownum;i++)
	{
		free(constantterm[i]);
		free(value0[i]);
		free(value1[i]);
		free(value2[i]);
		free(value3[i]);
		free(value4[i]);
	}
	free(constantterm);
	free(value0);
	free(value1);
	free(value2);
	free(value3);
	free(value4);
	for(i=0;i<128;i++)
	{
		free(Filter[i]);
		free(Filter1[i]);
		free(sFilter[i]);
		free(sFilter1[i]);
		free(Fcheck[i]);
		free(Fcheck1[i]);
		free(sFcheck[i]);
		free(sFcheck1[i]);
		free(T2Filter[i]);
		free(T2Filter1[i]);
		free(T2Fcheck[i]);
		free(T2Fcheck1[i]);
		//free(Fpos[i]);
	}
	free(Filter);
	free(Filter1);
	free(sFilter);
	free(sFilter1);
	free(Fcheck);
	free(Fcheck1);
	free(sFcheck);
	free(sFcheck1);
	free(T2Fcheck);
	free(T2Fcheck1);
	free(T2Filter);
	free(T2Filter1);
	free(Fpos);
	fclose(fp2);
	fclose(Sdim);
	return cubenum;
}

 ///只需要这个函数并行即可,现不并行,首先在设备端实现
 //需要在每一个线程中重复装载密钥


//接下来需要将线性检测改成是host端程序，在其中调用device端的求和程序

void getIndex(int **canindex)
{
	FILE *fp;
	fopen_s(&fp, "candiind", "r");
	//
	int i,j,m=0,l=0;
	int cubenum = 838;
	char c;
	char buff[1000] = { 0 };
	c = fgetc(fp);
	char X[80] = { 0 };
	int recround[10] = { 0 };
	int dim = 0;
	int maxround = 0;
	while (c != EOF)
	{
		//
		memset(buff, 0, sizeof(char) * 1000);
		j = 0;
		while (c != '\n')
		{
			buff[j++] = c;
			c = fgetc(fp);
		}
		c = fgetc(fp);
		m = 0;
		i = 0;
		int flag=0;
		//printf("%d: ", l);
		while(i<j)
		//for (i = 0; i < j; i++)
		{
			if ((buff[i]>='0') && (buff[i]<='9'))
			{
				flag=0;
				if (buff[i + 1] == ',' && flag==0)
				{
					canindex[l][m++] = buff[i] - '0';
					i = i + 2;
					flag=1;
				}
				if (buff[i + 2] == ',' &&flag==0)
				{
					canindex[l][m++] = (buff[i] - '0')*10+(buff[i+1] - '0');
					i = i + 3;
					flag=1;
				}
				if (buff[i + 3] == ',' &&flag==0)
				{
					canindex[l][m++] = (buff[i] - '0')*100+(buff[i+1] - '0')*10+(buff[i+2] - '0');
					i = i + 4;
					flag=1;
				}
				else
				{
					if(flag==0)
					{
						canindex[l][m]=0;
						int tmp=j-i-1,tt;
						int ti=1;
						//while(i<j)
						for(tt=0;tt<tmp;tt++)
						{
							canindex[l][m]+=(buff[j-2-tt]-'0')*ti;
							ti*=10;
						}
						m++;
						i=j;
					}
				}
			}
		}
		//cancubedim[l]=m;
		l++;
	}
	fclose(fp);
}
//线程并行

int main()
{
	clock_t t1,t2;
	u32 roundnum;
	u32 dim;
	roundnum=805;
	int i;
	dim=40;
	//u32 cube[40]={4,6,10,11,25,17,19,21,25,29,32,34,36,39,41,43,50,2,70,0,15,8,27,26,79,1,13,28,45,38,23,9,47,76,67,24,42,57,71,72};
	u32 cube[40]={ 2,4,6,10,11,12,15,17,19,21,23,25,29,34,36,41,0,70,8,16,79,27,45,26,28,31,77,38,47,13,1,62,49,64,40,39,43,50,58,74 };
	//u32 cube[31]={0,2,4,6,8,10,13,15,17,19,21,23,25,27,28,29,32,34,36,38,39,41,43,45,47,48,53,69,71,75,79,};//dim 31 for 805-round
	//u32 cube[22]={77,73,71,70,60,56,55,50,47,46,45,37,32,30,28,27,26,22,18,15,6,2};
	int dimlist[12]={21,21,21,22,22,22,23,23,23,24};
	u32 totalnum;
	u8 lin_test[32];
	//printf("Enter roundnum and totalnum\n");
	//scanf("%d, %d, %d", &roundnum, &totalnum,&dim);
	//printf("%u,%u,%u\n",roundnum,dim,totalnum);
	char filename[40];
	sprintf(filename,"result_round(%d)_dim(%d)",roundnum,dim);
	int **canindex;
	int candinum=838;
	canindex=(int**)malloc(sizeof(int*)*candinum);
	for(i=0;i<candinum;i++)
	{
		canindex[i]=(int *)malloc(sizeof(int)*2);
		memset(canindex[i],0,sizeof(int)*2);
	}
	getIndex(canindex);
	for(i=0;i<1;i++)
	{
		printf("%d %u\n", canindex[i][0],canindex[i][1]);
	}
	t1=clock();
	//GetSum();
	for(i=0;i<1;i++)
	{
		printf("\n***********%d*************\n",i);
		linearity_test_dynamicV6(cube,dim,roundnum,canindex,candinum,filename);
	}
	t2=clock();
	for(i=0;i<candinum;i++)
		free(canindex[i]);
	free(canindex);
	printf("\n%dms\n",t2-t1);
	system("pause");
	return 0;
}