#### CENTER 인증 보안 개선 공유
---
#### 목차
1. 인증 개요
2. 기존현황
3. 문제제기
4. 개선
4. 추가 개선
---
#### 1 . 인증 개요
먼저 기본적 인증에 대하여 잠시 알아보도록 하겠습니다. 보안 관련 전문가가 아니라, 잘못된 내용이 있을수 있습니다. 개략적 내용은 [OWASP](https://ko.wikipedia.org/wiki/OWASP) 에서 살펴볼수 있습니다.

대전제는 `100% 안전한 보안은 없다` 입니다. 보안은 어떤 방식으로든 뚫릴수 있으며, 웹에서는 최대한 뚫리기 어렵게 만드는 것이 목표입니다.

다만 서버 처리 효율성을 감안해야 합니다. 
대표적인 인증 방안을 살펴보겠습니다.

- 전통적인증
  - 약속한 api key 로 호출
- 쿠키
  - 인증 정보를 쿠키에 담는다
- 세션
  - 인증정보는 세션에 키는 쿠키에 저장한다
  - 세션키는 다음과같은 사항을 준수해야한다
     - 통신경로 암호화
     - 세션 타임아웃을 짧게
     - 세션 ID의 랜덤화
- JWT
    - 개요
      - 토큰자체에 데이터 포함 - 서버저장 필요없음
      - 데이터는 signature를 포함하여 변조방지
    - 장점 
      - 간편하고 변조방지로 인하여 보안성우수
    - 단점 
      - 데이터가 드러난다(민감한정보에 주의)
      - 키길이가 길어질수있다
      - 필요시 토큰만료 시키기가 불가능하다

원론적인 이야기와는 다르게 우리는 서비스를 하는 사람이기때문에 위 방법을 혼합하여 서버 효율성과 보안성을 조율하여 주로 사용합니다.  
JWT를 서버에 저장 안하는 방식이라고 해서, 그대로 사용한다면 권한 회수에 대한 부분을 감안해야 하는것입니다.

따라서, 기존 center 인증은 JWT 이용하여 서버에 저장하는 방식으로 보완되었습니다. 

---
#### 2. 기존 방안
- 기본 보안사항
   - nx blocker
   - cookie secure
   - 만료시간 존재(24h)
   - http only [X]
   - csrf 토큰 [X]
    
- JWT 를 쿠키 및 서버에 저장
---
#### 3. 기존 문제 
- 관련 이슈 #3445
1. history table을 session(JWT) 저장소로 이용
    - 조회 성능 감소
    - history table 비대화
2. JWT 자체 단점
   - client 정보 공개
   - JWT 길이에 따른네트워크 부하
3. 중복로그인으로 인한 세션키 증가 문제
   - 보안성과 서버처리 효율성 고려필요
---
#### 3. 개선방안
1. JWT에서 랜덤 세션키로
     -  보안성
      - [OWASP 세션키권고기준](https://www.owasp.org/index.php/Insufficient_Session-ID_Length) : 128비트 이상의 세션키길이 필요
      - 40개의 radomAlpha에 대한 확률적 계산을 해보면
         - 128비트 길이의 세션키라고 함은 2^128개의 경우의 수이상으로 만들면 된다고 가정할수있는데, 2^128 은 대략 64^21 이고 RandomStringUtils.randomAlphanumeric 으로 생성하는 문자는 한자리에 62개(알파벳대소문자 52개 + 숫자 10개) 이므로 대략 21자리 이상이면 가이드에서 제시한기준치를 훨씬 상회함
   - 서버처리 효율성
     - 전부 저장시 만료를 고려했을때 최대 5백만건 저장으로 생각됨
   - 종합하면 nbase arc처리 고려시 무리없는 수준으로 전부 저장하는게 좋음
2. JWT 와 history를 분리
   - JWT 에 `random session key`를 부여하고, nbase acr에 random session key : JWT 를 저장
     - random session key : 40자리 alpha numeric
     - random session key를 사용자 쿠키에 저장
3. 효과
   - history table 효율화 및 조회 성능개선
      - history는 로그 쌓는 용도로만 
      - 조회는 nbase arc
   - session key 효율화로 네트웤 부하 감소
   - session key에 정보가 남지 않아서 보안성 강화
   - 서버 효율성이 올라갔고 보안성도 개선 됨
---
#### 4. 추가 개선
 - history table를 mysql을 이용해야 할까?
    - 통합인증서버 구축시 고려가능
       - history 요구사항
          - 조회가 편해야 한다
          - 오래 보관 될수록 좋다
          - 빠를 수록 좋다
       -  개선 대안
          1. 일 5백만건 정도는 `nelo` 이용가능
          2. `es-farm`을 이용할수도
          3. 기본 로깅은 `api g/w`를 이용 인증서버에서는 `file로 쌓고 rotate`만 해도?
  ---
  #### 5. 다른프로젝트는?
  - intenal api 
    - 사내 서비스에서 호출 특성상 단순한 프로토콜이 괜찮아 보임, 현재의 api토큰방식
    - 타 서비스 연동 부분의 개발방식 표준화는 고려해 볼수도?
  - iims2
    - iims2 보안 방식 준수 
    - 보안팀의 보안 검수 및  인증회피를 통한 공격 소요 보완 버전 - 2.0.0-p1으로 업그레이드
 - open api
   - 외부 개발자 페이지가 필요하지 않을까?
