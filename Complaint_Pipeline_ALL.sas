
/*######################## 00a_setup_taxonomy.sas ########################*/
/*==========================================================================
  00a  SETUP + 3-LEVEL TAXONOMY  (Base SAS / Enterprise Guide program node)
  Creates:  cmp.tax_l1, cmp.tax_l2, cmp.tax_l3, cmp.tax_trigger, cmp.kw_map
  Run once (re-run to reset the seed). Edit &root. to any writable folder.
==========================================================================*/
%let root = /sasdata/complaints;      /* EDIT: e.g. C:\Temp\cmp on Windows  */
libname cmp "&root.";
options nosymbolgen nomprint validvarname=v7;

/*---- LEVEL 1 : Domain / product area ------------------------------------*/
data cmp.tax_l1;
  length l1_id $4 l1_name $40 l1_desc $120 active_flag 8 valid_from valid_to 8;
  format valid_from valid_to date9.;
  infile datalines dlm='|' truncover;
  input l1_id $ l1_name $ l1_desc $;
  active_flag = 1; valid_from = '01JAN2026'd; valid_to = '31DEC9999'd;
  datalines;
PAY|Payments & Transfers|Money movement: faster payments, standing orders, cards, fraud and scams
ACC|Account Servicing|Access, changes, fees and charges on existing accounts
LND|Lending & Credit|Applications, affordability decisions, arrears and collections
SVC|Service & Conduct|How we communicated, handled the complaint and treated the customer
;
run;

/*---- LEVEL 2 : Sub-process / failure type (FK -> l1_id) ------------------*/
data cmp.tax_l2;
  length l2_id $6 l1_id $4 l2_name $50 active_flag 8;
  infile datalines dlm='|' truncover;
  input l2_id $ l1_id $ l2_name $;
  active_flag = 1;
  datalines;
PAY01|PAY|Failed or delayed payment
PAY02|PAY|Fraud and scam handling
ACC01|ACC|Account access and changes
ACC02|ACC|Fees and charges
LND01|LND|Application and decisioning
LND02|LND|Arrears and collections
SVC01|SVC|Communication and complaint handling
SVC02|SVC|Staff conduct and advice
;
run;

/*---- LEVEL 3 : Specific root cause (FK -> l2_id) -------------------------*/
data cmp.tax_l3;
  length l3_id $8 l2_id $6 l3_name $50 l3_def $160 active_flag 8;
  infile datalines dlm='|' truncover;
  input l3_id $ l2_id $ l3_name $ l3_def $;
  active_flag = 1;
  datalines;
PAY01.1|PAY01|System or processing fault|Payment failed or was delayed because of a system, batch or technical fault
PAY01.2|PAY01|Manual processing error|Payment failed or went wrong because a colleague keyed or actioned it incorrectly
PAY02.1|PAY02|Fraud alert not actioned|Fraud warning, block or report was not acted on in time
PAY02.2|PAY02|Inadequate scam warning|Customer was not given a clear scam warning or intervention
ACC01.1|ACC01|Lockout or verification friction|Customer could not access the account because of ID or security checks
ACC01.2|ACC01|Incorrect account change|Details or settings were changed wrongly or without consent
ACC02.1|ACC02|Fee wrongly applied|A fee or charge was applied that should not have been
ACC02.2|ACC02|Fee not disclosed|Fee or interest was not made clear before it applied
LND01.1|LND01|Incorrect affordability decision|Application declined or approved on wrong affordability assessment
LND01.2|LND01|Application delay|Application or decision took longer than promised
LND02.1|LND02|Inappropriate arrears contact|Collections contact was too frequent, wrong channel or wrong tone
LND02.2|LND02|Vulnerability not recognised|Signs of vulnerability were missed or not acted on
SVC01.1|SVC01|No response or chasing|Customer had to chase, or no reply was given within timescale
SVC01.2|SVC01|Incorrect information given|Customer was given wrong or conflicting information
SVC02.1|SVC02|Poor advice|Advice given was unsuitable or misleading
SVC02.2|SVC02|Unprofessional handling|Rude, dismissive or unprofessional treatment
;
run;

/*---- Trigger categories (WHY the customer felt compelled to complain) ----*/
data cmp.tax_trigger;
  length trg_id $4 trg_name $40 trg_def $100;
  infile datalines dlm='|' truncover;
  input trg_id $ trg_name $ trg_def $;
  datalines;
T01|Financial loss or hardship|Money lost, charged or put at risk
T02|Time and effort lost|Chasing, waiting, repeated contact
T03|Trust and fairness|Felt misled, ignored or treated unfairly
T04|Distress and anxiety|Worry, stress, embarrassment
T05|Anger and outrage|Strong anger, unacceptable service
;
run;

/*######################## 00b_keyword_map.sas ########################*/
/*==========================================================================
  00b  KEYWORD MAP  (what you type is normalised by the SAME pipeline as the
  complaint text - see 04 - so plural/tense/stopword differences don't matter)
  kw_type = ROOT    -> l3_id populated  (root-cause evidence)
  kw_type = TRIGGER -> trg_id populated (customer emotion / intent evidence)
  kw_weight: 1.0 = strong/specific   0.5 = supportive   0.25 = weak
==========================================================================*/
data cmp.kw_map;
  length kw_id 8 kw_type $7 l3_id $8 trg_id $4 keyword $60 kw_weight 8 source $8;
  infile datalines dlm='|' dsd truncover;   /* DSD: '||' = missing value */
  input kw_type $ l3_id $ trg_id $ keyword $ kw_weight;
  kw_id = _n_; source = 'SEED';
  datalines;
ROOT|PAY01.1||system error|1
ROOT|PAY01.1||system outage|1
ROOT|PAY01.1||technical fault|1
ROOT|PAY01.1||payment failed|0.5
ROOT|PAY01.2||keying error|1
ROOT|PAY01.2||wrong account|0.5
ROOT|PAY01.2||manual error|1
ROOT|PAY01.2||processed incorrectly|1
ROOT|PAY02.1||fraud alert|0.5
ROOT|PAY02.1||failed to block|1
ROOT|PAY02.1||did not act|0.5
ROOT|PAY02.1||fraud team delay|1
ROOT|PAY02.2||scam warning|1
ROOT|PAY02.2||no warning|0.5
ROOT|PAY02.2||should have intervened|1
ROOT|ACC01.1||locked out|1
ROOT|ACC01.1||verification failed|1
ROOT|ACC01.1||security check|0.5
ROOT|ACC01.2||changed without consent|1
ROOT|ACC01.2||details amended|0.5
ROOT|ACC01.2||incorrect change|1
ROOT|ACC02.1||fee applied incorrectly|1
ROOT|ACC02.1||charged twice|1
ROOT|ACC02.1||refund fee|0.5
ROOT|ACC02.2||fee not disclosed|1
ROOT|ACC02.2||not made clear|0.5
ROOT|ACC02.2||terms unclear|0.5
ROOT|LND01.1||affordability assessment|1
ROOT|LND01.1||declined incorrectly|1
ROOT|LND01.1||income miscalculated|1
ROOT|LND01.2||application delay|1
ROOT|LND01.2||decision took longer|1
ROOT|LND01.2||awaiting decision|0.5
ROOT|LND02.1||excessive calls|1
ROOT|LND02.1||collections contact|0.5
ROOT|LND02.1||arrears letter|0.5
ROOT|LND02.2||vulnerability|1
ROOT|LND02.2||did not recognise|0.5
ROOT|LND02.2||bereavement|0.5
ROOT|SVC01.1||no response|1
ROOT|SVC01.1||failed to reply|1
ROOT|SVC01.1||chased|0.5
ROOT|SVC01.2||incorrect information|1
ROOT|SVC01.2||wrongly told|1
ROOT|SVC01.2||conflicting advice|1
ROOT|SVC02.1||unsuitable advice|1
ROOT|SVC02.1||poor advice|1
ROOT|SVC02.1||misled|0.5
ROOT|SVC02.2||rude|1
ROOT|SVC02.2||dismissive|1
ROOT|SVC02.2||unprofessional|1
TRIGGER||T01|out of pocket|1
TRIGGER||T01|hardship|1
TRIGGER||T01|lost money|1
TRIGGER||T01|overdrawn|0.5
TRIGGER||T02|hours on the phone|1
TRIGGER||T02|still waiting|1
TRIGGER||T02|had to chase|1
TRIGGER||T02|waited weeks|1
TRIGGER||T03|not fair|1
TRIGGER||T03|ignored|1
TRIGGER||T03|misled|1
TRIGGER||T03|lied|1
TRIGGER||T04|stressed|1
TRIGGER||T04|anxious|1
TRIGGER||T04|worried|0.5
TRIGGER||T04|embarrassed|1
TRIGGER||T05|disgusted|1
TRIGGER||T05|furious|1
TRIGGER||T05|appalling|1
TRIGGER||T05|unacceptable|1
;
run;

/*---- Integrity check: every keyword must point at a valid parent ---------*/
proc sql;
  title 'ORPHAN KEYWORDS (should return 0 rows)';
  select k.kw_id, k.keyword from cmp.kw_map k
   where (k.kw_type='ROOT'    and k.l3_id  not in (select l3_id  from cmp.tax_l3))
      or (k.kw_type='TRIGGER' and k.trg_id not in (select trg_id from cmp.tax_trigger));
quit;
title;

/*######################## 00c_support_and_sample.sas ########################*/
/*==========================================================================
  00c  SUPPORT TABLES + SAMPLE DATA
  cmp.stopwords, cmp.lemma_map, cmp.weight_matrix, cmp.complaints_raw
  NOTE: negations (not, no, never) are deliberately NOT stopwords.
==========================================================================*/
data cmp.stopwords;
  length word $40;
  infile datalines dlm=' ' truncover;
  input word :$40. @@;
  datalines;
a an the and or but if of to in on at by for with from as is are was were be been
being am it its this that these those i me my we our us you your he she they them
their have has had do does did done would could should will can may might must
so than then there here when what which who whom how why also just very really
please thank thanks dear regards sincerely hello hi again about into over under
out up down off after before while during because since until per via etc
;
run;

data cmp.lemma_map;                        /* irregular forms the suffix stripper can't fix */
  length word $40 lemma $40;
  infile datalines dlm=' ' truncover;
  input word :$40. lemma :$40. @@;
  datalines;
paid pay sent send told tell gave give took take lost lose kept keep made make
wrote write bought buy said say went go got get knew know felt feel left leave
charged charge refunded refund declined decline
;
run;

/*---- Weight matrix: how much each (field, section) counts, per purpose ---*/
data cmp.weight_matrix;
  length purpose $7 field $1 sect $7 w 8 rationale $70;
  infile datalines dlm='|' truncover;
  input purpose $ field $ sect $ w rationale $;
  datalines;
ROOT|D|CUST|0.35|Customer view: useful pointer, not proof of cause
ROOT|D|VENT|0.05|Venting: almost no causal information
ROOT|F|UPHELD|1.00|Business agreed: strongest root-cause evidence
ROOT|F|NEUTRAL|0.50|Investigation fact, no determination
ROOT|F|NOTUP|-0.30|Rejected aspect: evidence this is NOT the cause
ROOT|F|ADMIN|0.00|Case-handling notes: never a cause
TRIGGER|D|CUST|1.00|Customer own words drive trigger and emotion
TRIGGER|D|VENT|0.80|Venting is the best emotion signal
TRIGGER|F|UPHELD|0.20|Business acknowledgement of impact
TRIGGER|F|NEUTRAL|0.10|Little emotional content
TRIGGER|F|NOTUP|0.00|Not relevant to trigger
TRIGGER|F|ADMIN|0.00|Case-handling notes
;
run;

/*---- Sample complaints so the pipeline runs end-to-end -------------------*/
data cmp.complaints_raw;
  length complaint_id 8 description $1000 findings_of_investigation $1000;
  infile datalines dlm='|' truncover;
  input complaint_id description $ findings_of_investigation $;
  datalines;
1001|My standing order failed for the third month and I was charged twice for the overdraft. I have spent hours on the phone and I am furious. Absolutely disgraceful service!|Call ref 88231 logged. We reviewed the payment history and found the standing order failed because of a system error during the batch run. This aspect of the complaint is upheld. The overdraft charges were refunded.
1002|I was locked out of my account for two weeks and nobody would help. I am stressed and worried about my rent.|Case opened and forwarded to the security team. The verification failed because the ID check flagged a mismatch. We should have offered an alternative route. The complaint is upheld. We did not find evidence the account was closed in error.
1003|The advisor was rude and dismissive on the phone and told me the wrong thing about my loan. This is unacceptable.|We listened to the call recording. The advisor was not rude and acted professionally. This part is not upheld. However the advisor gave incorrect information about the settlement figure, which is upheld.
1004|Your collections team keep calling me daily even though I told them about my bereavement. I feel harassed and embarrassed.|Reviewed by team leader. Vulnerability was not recorded on the account so the collections contact continued. We did not recognise the bereavement. Complaint upheld and account notes updated.
1005|I sent money to what turned out to be a scammer. The bank gave me no warning at all. I am out of pocket and it is not fair.|The payment was in line with the customer instructions. We found the scam warning shown at the time was appropriate. Complaint not upheld. Email sent to the customer explaining the outcome.
1006|My loan application has been awaiting a decison for six weeks and I still waiting for an answer. I had to chase every week.|Application delay confirmed. The decision took longer than our standard because the file was queued. We agree this was our error. Complaint upheld. Compensation paid.
1007|A fee was applied to my acount and I was never told about it. Charges were not made clear.|We reviewed the account terms. The fee was correctly applied under the terms. Fee not disclosed at point of sale was not evidenced. Not upheld.
1008|They keyed my payment to the wrong account and I lost money. I feel misled and ignored.|The payment was processed incorrectly due to a manual error by the colleague who keyed the sort code. Upheld. Funds were recovered. Case closed.
;
run;

/*######################## 01_segment_tokenise_ngrams.sas ########################*/
/*==========================================================================
  01  SENTENCE SEGMENTATION, NOISE TAGGING, TOKENISATION, N-GRAMS
  In : cmp.complaints_raw, cmp.stopwords, (cmp.lemma_map when stem=1)
  Out: cmp.sentences  (one row per sentence, tagged with a section)
       cmp.ngrams_raw (unigrams, bigrams, trigrams on cleaned tokens)

  SECT codes
    description : CUST (factual customer narrative) | VENT (short pure venting)
    findings    : UPHELD | NOTUP (rejected aspect) | NEUTRAL | ADMIN (handler notes)
==========================================================================*/

/*---- 1. Split both fields into sentences and tag each one ----------------*/
data cmp.sentences;
  set cmp.complaints_raw;
  length field $1 text $2000 sent_text $600 sect $7;
  retain re_admin re_notup re_up re_vent;
  if _n_ = 1 then do;
    re_admin = prxparse('/\b(call ref|case (opened|closed|logged)|logged|forwarded to|email sent|reviewed by|team leader|listened to the call|acknowledg\w*|compensation paid|funds were recovered|notes updated)\b/i');
    re_notup = prxparse('/\b(not upheld|no evidence|did not find|acted (correctly|professionally)|was not rude|in line with|was appropriate|correctly applied|not evidenced)\b/i');
    re_up    = prxparse('/\b(upheld|we agree|our error|should have|was not recorded|we did not recognise|confirmed|failed because|due to a)\b/i');
    re_vent  = prxparse('/\b(disgrace\w*|outrage\w*|appalling|ridiculous|absolutely|furious|fed up|joke|useless|shambles)\b/i');
  end;

  do field = 'D', 'F';
    if field = 'D' then text = description; else text = findings_of_investigation;
    text = prxchange('s/(\d)\.(\d)/$1~$2/', -1, text);     /* protect decimals */
    nsent = countw(text, '.!?');
    do sent_no = 1 to nsent;
      sent_text = strip(translate(scan(text, sent_no, '.!?'), '.', '~'));
      if lengthn(sent_text) < 3 then continue;
      if field = 'D' then do;
        if prxmatch(re_vent, sent_text) and countw(sent_text, ' ') <= 10 then sect = 'VENT';
        else sect = 'CUST';
      end;
      else do;
        if      prxmatch(re_admin, sent_text) and not prxmatch(re_up, sent_text) then sect = 'ADMIN';
        else if prxmatch(re_notup, sent_text) then sect = 'NOTUP';  /* checked BEFORE upheld: "not upheld" contains "upheld" */
        else if prxmatch(re_up,    sent_text) then sect = 'UPHELD';
        else sect = 'NEUTRAL';
      end;
      output;
    end;
  end;
  keep complaint_id field sent_no sent_text sect;
run;

/*---- 2. Reusable tokeniser / n-gram macro --------------------------------*/
%macro make_ngrams(in=cmp.sentences, out=cmp.ngrams_raw, stem=0, maxn=3);
data &out.(keep=complaint_id field sent_no sect n ngram);
  set &in.(where=(sect ne 'ADMIN'));            /* admin notes never reach the vocabulary */
  length word $40 lemma $40 w $40 clean $700 ngram $120;
  array kw{200} $40 _temporary_;
  if _n_ = 1 then do;
    declare hash sw(dataset:'cmp.stopwords');
    sw.definekey('word'); sw.definedone();
    %if &stem. %then %do;
      declare hash lm(dataset:'cmp.lemma_map');
      lm.definekey('word'); lm.definedata('lemma'); lm.definedone();
    %end;
  end;

  clean = compbl(prxchange('s/[^a-z0-9 ]/ /', -1, lowcase(sent_text)));
  k = 0;
  do p = 1 to countw(clean, ' ');
    w = scan(clean, p, ' ');
    if lengthn(w) < 2 then continue;
    if anydigit(w) and not anyalpha(w) then continue;     /* pure numbers */
    word = w;
    if sw.check() = 0 then continue;                       /* stopword */
    %if &stem. %then %do;
      lemma = ' ';
      if lm.find() = 0 then w = lemma;                     /* irregular -> lemma */
      w = stemw(w);                                        /* suffix stripping (FCMP, file 02) */
    %end;
    if k >= 200 then leave;
    k + 1;
    kw{k} = w;
  end;

  do n = 1 to &maxn.;
    do i = 1 to k - n + 1;
      ngram = kw{i};
      do j = 1 to n - 1;
        ngram = catx(' ', ngram, kw{i + j});
      end;
      output;
    end;
  end;
run;
%mend make_ngrams;

%make_ngrams(in=cmp.sentences, out=cmp.ngrams_raw, stem=0);

proc freq data=cmp.sentences; tables field*sect / nopercent norow nocol; run;
proc sql outobs=15;
  title 'Top raw bigrams'; select ngram, count(*) as freq from cmp.ngrams_raw
   where n=2 group by ngram order by freq desc;
quit; title;

/*######################## 02_stem_lemma_phonetic.sas ########################*/
/*==========================================================================
  02  STEMMING, "LEMMING" APPROXIMATION, PHONETIC KEYS
  - stemw()      : regex suffix stripper (PROC FCMP wrapping PRXCHANGE)
  - cmp.lemma_map: irregular forms handled by hash lookup BEFORE stemming
  - soundex()    : phonetic key, used later as a fuzzy-match booster
  Out: cmp.ngrams_stem, cmp.kw_norm (keywords run through the SAME pipeline)
==========================================================================*/
proc fcmp outlib=cmp.funcs.text;
  function stemw(w $) $ 40;
    length s t $ 40;
    s = lowcase(strip(w));
    if lengthn(s) <= 3 then return(s);
    s = prxchange('s/sses$/ss/', 1, s);                            /* addresses -> address */
    if lengthn(s) > 4 then s = prxchange('s/ies$/y/', 1, s);       /* queries  -> query   */
    if lengthn(s) > 3 and prxmatch('/[^s]s$/', s) then
      s = substr(s, 1, lengthn(s) - 1);                            /* charges -> charge   */
    if prxmatch('/(ing|ed)$/', s) then do;
      t = prxchange('s/(ing|ed)$//', 1, s);
      if lengthn(t) >= 3 and prxmatch('/[aeiouy]/', t) then do;    /* must keep a vowel   */
        s = prxchange('s/([^aeioulsz])\1$/$1/', 1, t);             /* runn -> run         */
      end;
    end;
    if lengthn(s) > 3 then s = prxchange('s/e$//', 1, s);          /* charge -> charg     */
    if lengthn(s) > 5 then s = prxchange('s/(ment|ness)$//', 1, s);/* payment -> pay      */
    if lengthn(s) > 5 then s = prxchange('s/ly$//', 1, s);         /* incorrectly -> incorrect */
    if lengthn(s) > 3 and prxmatch('/[^aeiou]y$/', s) then
      s = cats(substr(s, 1, lengthn(s) - 1), 'i');                 /* apply/applied -> appli */
    return(s);
  endsub;
run;
options cmplib=cmp.funcs;

/*---- Quick self-test: eyeball the stemmer -------------------------------*/
data _stem_test;
  length word $30 stem $30 sdx $6;
  input word :$30. @@;
  stem = stemw(word); sdx = soundex(stem);
  datalines;
charges charged charging payment payments delayed delaying delays refused refuse
processing processed process queries complaints declined decline running address
;
run;
proc print data=_stem_test noobs; run;

/*---- Stemmed / lemmatised n-grams (same macro as step 01) ----------------*/
%make_ngrams(in=cmp.sentences, out=cmp.ngrams_stem, stem=1);

/*---- Normalise the keyword map through the identical pipeline ------------*/
data cmp.kw_norm;
  set cmp.kw_map;
  length word $40 lemma $40 w $40 clean $200 kw_stem $120;
  if _n_ = 1 then do;
    declare hash sw(dataset:'cmp.stopwords');
    sw.definekey('word'); sw.definedone();
    declare hash lm(dataset:'cmp.lemma_map');
    lm.definekey('word'); lm.definedata('lemma'); lm.definedone();
  end;
  clean = compbl(prxchange('s/[^a-z0-9 ]/ /', -1, lowcase(keyword)));
  ngram_n = 0; kw_stem = ' ';
  do p = 1 to countw(clean, ' ');
    w = scan(clean, p, ' ');
    word = w;
    if sw.check() = 0 then continue;
    lemma = ' ';
    if lm.find() = 0 then w = lemma;
    w = stemw(w);
    kw_stem = catx(' ', kw_stem, w);
    ngram_n + 1;
  end;
  kw_sdx = soundex(compress(kw_stem));
  if ngram_n in (1, 2, 3);          /* drop keywords that collapse to nothing or exceed trigram */
  drop word lemma w clean p;
run;

proc sql;
  title 'Keywords that collapsed after stopword removal (review these)';
  select kw_id, keyword, kw_stem, ngram_n from cmp.kw_norm where ngram_n = 1 and countw(keyword,' ') > 1;
quit; title;

/*######################## 03_tfidf.sas ########################*/
/*==========================================================================
  03  TF-IDF  (PROC SQL for corpus statistics, HASH for the row-level join)
  Document = one complaint.  Term = stemmed n-gram (1-3).
  Tunables: &min_df. drops one-off typos/noise, &max_df_pct. drops boilerplate
  In : cmp.ngrams_stem
  Out: cmp.tf, cmp.df_idf, cmp.tfidf (L2-normalised per complaint+field)
==========================================================================*/
%let min_df     = 1;      /* raise to 2+ on a real corpus (25k rows: try 3) */
%let max_df_pct = 0.80;   /* ignore terms appearing in >80% of complaints  */

/*---- 1. Term frequency per complaint+field, sub-linear (1 + ln tf) -------*/
proc sql;
  create table cmp.tf as
  select complaint_id, field, n, ngram, count(*) as tf,
         1 + log(count(*)) as tf_log
    from cmp.ngrams_stem
   group by complaint_id, field, n, ngram;

  /*---- 2. Document frequency + smoothed IDF ------------------------------*/
  select count(distinct complaint_id) into :ndocs trimmed from cmp.ngrams_stem;

  create table cmp.df_idf as
  select ngram, n, count(distinct complaint_id) as df,
         log((1 + &ndocs.) / (1 + count(distinct complaint_id))) + 1 as idf
    from cmp.ngrams_stem
   group by ngram, n
  having calculated df >= &min_df.
     and calculated df <= &max_df_pct. * &ndocs.;
quit;
%put NOTE: corpus size = &ndocs. complaints;

/*---- 3. Hash lookup join (much faster than SQL join on a big vocabulary) -*/
data cmp.tfidf_raw;
  if _n_ = 1 then do;
    length ngram $120 n 8 df 8 idf 8;
    declare hash h(dataset:'cmp.df_idf');
    h.definekey('ngram', 'n');
    h.definedata('df', 'idf');
    h.definedone();
    call missing(df, idf);
  end;
  set cmp.tf;
  if h.find() = 0 then do;
    tfidf = tf_log * idf;
    output;
  end;
run;

/*---- 4. L2-normalise each complaint+field vector (cosine-ready) ----------*/
proc sql;
  create table cmp.tfidf as
  select a.*, a.tfidf / b.norm as tfidf_norm
    from cmp.tfidf_raw a
    inner join (select complaint_id, field, sqrt(sum(tfidf**2)) as norm
                  from cmp.tfidf_raw group by complaint_id, field) b
      on a.complaint_id = b.complaint_id and a.field = b.field;
quit;

proc sql outobs=15;
  title 'Highest-weight terms in complaint 1001 (customer field)';
  select ngram, tf, round(idf,.01) as idf, round(tfidf,.01) as tfidf
    from cmp.tfidf where complaint_id=1001 and field='D' order by tfidf desc;
quit; title;

/*######################## 04_fuzzy_match.sas ########################*/
/*==========================================================================
  04  FUZZY SEARCH + STRING DISTANCE AGAINST THE TAXONOMY KEYWORDS
  Strategy: match the VOCABULARY once (distinct n-grams x keywords), not every
  row.  Then join the small mapping table back to the sentences.
  Tools: complev() (Levenshtein), spedis() (spelling distance), soundex() boost.
  In : cmp.df_idf, cmp.ngrams_stem, cmp.kw_norm, cmp.tfidf
  Out: cmp.match_map, cmp.kw_hits, cmp.sim_l3
==========================================================================*/
%let fz_min     = 0.80;   /* minimum similarity to accept a fuzzy match     */
%let fz_minlen  = 6;      /* never fuzzy-match very short strings (pay/day) */

/*---- 1. Vocabulary (all distinct stemmed n-grams, incl. pruned ones) -----*/
proc sql;
  create table work.vocab as
  select distinct ngram, n from cmp.ngrams_stem;

  /*---- 2. Exact matches ---------------------------------------------------*/
  create table work.exact as
  select v.ngram, v.n, k.kw_id, 1 as match_q, 'EXACT' as match_type length=5
    from work.vocab v inner join cmp.kw_norm k
      on v.ngram = k.kw_stem and v.n = k.ngram_n;

  /*---- 3. Fuzzy candidates: blocked by n-gram size and length band -------*/
  create table work.fz_cand as
  select v.ngram, v.n, k.kw_id, k.kw_stem,
         complev(strip(v.ngram), strip(k.kw_stem))            as lev,
         spedis (strip(v.ngram), strip(k.kw_stem))            as spd,
         (soundex(compress(v.ngram)) = k.kw_sdx)              as sdx_hit,
         max(length(v.ngram), length(k.kw_stem))              as maxlen
    from work.vocab v inner join cmp.kw_norm k
      on  v.n = k.ngram_n
      and abs(length(v.ngram) - length(k.kw_stem)) <= 3
      and length(v.ngram) >= &fz_minlen.
      and v.ngram ne k.kw_stem;
quit;

/*---- 4. Score candidates, keep the best keyword per (ngram, kw_id) -------*/
data work.fuzzy;
  set work.fz_cand;
  length match_type $5;
  sim_lev = 1 - lev / maxlen;
  sim_spd = max(0, 1 - spd / 100);
  match_q = max(sim_lev, sim_spd) + (0.05 * sdx_hit);
  match_q = min(match_q, 0.99);                 /* a fuzzy hit never equals an exact hit */
  match_type = 'FUZZY';
  if match_q >= &fz_min.;
  keep ngram n kw_id match_q match_type;
run;

data cmp.match_map;
  set work.exact work.fuzzy;
run;

/*---- 5. Row-level hits, carrying the field and section tags -------------*/
proc sql;
  create table cmp.kw_hits as
  select g.complaint_id, g.field, g.sect, g.sent_no,
         k.kw_id, k.kw_type, k.l3_id, k.trg_id, k.kw_weight,
         m.match_type, m.match_q,
         coalesce(d.idf, 1) as idf
    from cmp.ngrams_stem g
    inner join cmp.match_map m on g.ngram = m.ngram and g.n = m.n
    inner join cmp.kw_norm   k on m.kw_id = k.kw_id
    left  join cmp.df_idf    d on g.ngram = d.ngram and g.n = d.n;
quit;

/*---- 6. Similarity matrix: complaint vector vs. L3 keyword vector --------*/
proc sql;
  create table cmp.sim_l3 as
  select t.complaint_id, t.field, k.l3_id,
         sum(t.tfidf_norm * k.kw_weight * m.match_q)
           / sqrt(l.kw_norm2) as cosine
    from cmp.tfidf t
    inner join cmp.match_map m on t.ngram = m.ngram and t.n = m.n
    inner join cmp.kw_norm   k on m.kw_id = k.kw_id and k.kw_type = 'ROOT'
    inner join (select l3_id, sum(kw_weight**2) as kw_norm2
                  from cmp.kw_norm where kw_type = 'ROOT' group by l3_id) l
      on k.l3_id = l.l3_id
   group by t.complaint_id, t.field, k.l3_id, l.kw_norm2;
quit;

proc sql;
  title 'Fuzzy matches accepted (audit these before trusting them)';
  select ngram, kw_id, put(match_q, 5.2) as sim from cmp.match_map where match_type = 'FUZZY';
quit; title;

/*######################## 05_dual_field_scoring.sas ########################*/
/*==========================================================================
  05  WEIGHTED DUAL-FIELD SCORING  ->  ROOT CAUSE (L1/L2/L3) + TRIGGER + EMOTION
  hit_score = kw_weight x match_quality x idf_boost x weight_matrix(purpose, field, sect)
    ROOT    purpose: findings UPHELD sentences dominate (1.00), customer text is a
                     pointer (0.35), rejected (NOTUP) evidence is subtracted (-0.30)
    TRIGGER purpose: customer text dominates (1.00), venting still counts (0.80)
  Repeats of one keyword get diminishing returns: (1 + ln count) / count.
  In : cmp.kw_hits, cmp.weight_matrix, cmp.sentences, cmp.df_idf, cmp.tax_*
  Out: cmp.class_evidence, cmp.complaint_class
==========================================================================*/
%let min_root  = 0.40;    /* minimum root score to auto-classify            */
%let min_conf  = 0.55;    /* top / (top + runner-up) needed to auto-classify */
%let emo_high  = 1.50;    /* emotion index bands                            */
%let emo_med   = 0.75;

proc sql noprint;
  select max(idf) into :idf_ref trimmed from cmp.df_idf;
quit;

/*---- 1. Weight every hit --------------------------------------------------*/
proc sql;
  create table work.hit_w as
  select h.*,
         h.kw_weight * h.match_q * (0.5 + 0.5 * min(h.idf / &idf_ref., 1)) * w.w as hit_score
    from cmp.kw_hits h
    inner join cmp.weight_matrix w
       on w.purpose = h.kw_type and w.field = h.field and w.sect = h.sect;

  /*---- 2. Per keyword: damp repeats, keep the D and F contributions apart -*/
  create table cmp.class_evidence as
  select h.complaint_id, h.kw_type, h.l3_id, h.trg_id, h.kw_id, k.keyword,
         count(*) as cnt,
         (1 + log(calculated cnt)) / calculated cnt
           * sum(case when h.field = 'D' then h.hit_score else 0 end) as d_score,
         (1 + log(calculated cnt)) / calculated cnt
           * sum(case when h.field = 'F' then h.hit_score else 0 end) as f_score
    from work.hit_w h inner join cmp.kw_map k on h.kw_id = k.kw_id
   group by h.complaint_id, h.kw_type, h.l3_id, h.trg_id, h.kw_id, k.keyword;

  /*---- 3. Roll up to L3 candidates and to trigger categories -------------*/
  create table work.root as
  select complaint_id, l3_id, sum(d_score) as d_score, sum(f_score) as f_score,
         sum(d_score + f_score) as root_score
    from cmp.class_evidence where kw_type = 'ROOT'
   group by complaint_id, l3_id;

  create table work.trig as
  select complaint_id, trg_id, sum(d_score + f_score) as trg_score
    from cmp.class_evidence where kw_type = 'TRIGGER'
   group by complaint_id, trg_id;

  create table work.emo as
  select complaint_id, sum(trg_score) as emo_index from work.trig group by complaint_id;

  /*---- 4. Investigation profile: how much did the business uphold? -------*/
  create table work.f_profile as
  select complaint_id,
         sum(field = 'F' and sect = 'UPHELD') as n_up,
         sum(field = 'F' and sect = 'NOTUP')  as n_notup,
         sum(field = 'D' and sect = 'VENT')   as n_vent
    from cmp.sentences group by complaint_id;
quit;

/*---- 5. Pick winners (sorted descending, first two rows per complaint) ----*/
proc sort data=work.root; by complaint_id descending root_score; run;
data work.root_top;
  set work.root; by complaint_id;
  length top_l3 $8;
  retain rank top_l3 top_score top_d top_f second_score;
  if first.complaint_id then do; rank = 0; second_score = 0; end;
  rank + 1;
  if rank = 1 then do; top_l3 = l3_id; top_score = root_score; top_d = d_score; top_f = f_score; end;
  else if rank = 2 then second_score = root_score;
  if last.complaint_id then do;
    conf = ifn(top_score > 0, top_score / (top_score + max(second_score, 0)), .);
    output;
  end;
  keep complaint_id top_l3 top_score top_d top_f second_score conf;
run;

proc sort data=work.trig; by complaint_id descending trg_score; run;
data work.trig_top;
  set work.trig; by complaint_id;
  if first.complaint_id then output;
  keep complaint_id trg_id trg_score;
run;

/*---- 6. Assemble the classification with status logic ---------------------*/
proc sql;
  create table work.assembled as
  select c.complaint_id, r.top_l3 as l3_id, r.top_score as root_score,
         r.top_d as root_from_customer, r.top_f as root_from_findings,
         r.conf as root_conf, t.trg_id, t.trg_score, e.emo_index,
         p.n_up, p.n_notup, p.n_vent
    from cmp.complaints_raw c
    left join work.root_top r on c.complaint_id = r.complaint_id
    left join work.trig_top t on c.complaint_id = t.complaint_id
    left join work.emo      e on c.complaint_id = e.complaint_id
    left join work.f_profile p on c.complaint_id = p.complaint_id;

  create table cmp.complaint_class as
  select a.*, l3.l3_name, l2.l2_id, l2.l2_name, l1.l1_id, l1.l1_name, tr.trg_name
    from work.assembled a
    left join cmp.tax_l3 l3      on a.l3_id  = l3.l3_id
    left join cmp.tax_l2 l2      on l3.l2_id = l2.l2_id
    left join cmp.tax_l1 l1      on l2.l1_id = l1.l1_id
    left join cmp.tax_trigger tr on a.trg_id = tr.trg_id;
quit;

data cmp.complaint_class;
  set cmp.complaint_class;
  length class_status $22 emo_band $6 outcome_signal $10;
  if      n_up > 0 and n_notup > 0 then outcome_signal = 'PARTIAL';
  else if n_up > 0                 then outcome_signal = 'UPHELD';
  else if n_notup > 0              then outcome_signal = 'NOT UPHELD';
  else                                  outcome_signal = 'NONE';

  if      root_score >= &min_root. and root_conf >= &min_conf. and root_from_findings > 0
                                                   then class_status = 'CLASSIFIED';
  else if root_score ne . and root_from_findings <= 0 and outcome_signal = 'NOT UPHELD'
                                                   then class_status = 'ALLEGED_NOT_UPHELD';
  else if root_score > 0 and root_from_findings <= 0
                                                   then class_status = 'CUSTOMER_VIEW_ONLY';
  else if root_score > 0                           then class_status = 'LOW_CONFIDENCE_REVIEW';
  else                                                  class_status = 'UNCLASSIFIED';

  emo_index = coalesce(emo_index, 0);
  if      emo_index >= &emo_high. then emo_band = 'HIGH';
  else if emo_index >= &emo_med.  then emo_band = 'MEDIUM';
  else                                 emo_band = 'LOW';
run;

proc print data=cmp.complaint_class noobs label;
  var complaint_id l1_name l2_name l3_name root_score root_conf class_status
      outcome_signal trg_name emo_index emo_band;
  format root_score root_conf emo_index 5.2;
run;

/*---- Explainability: why did complaint 1005 end up where it did? ----------*/
proc print data=cmp.class_evidence noobs;
  where complaint_id = 1005;
  var kw_type keyword cnt d_score f_score;
run;

/*######################## 06_schema_constraints.sas ########################*/
/*==========================================================================
  06  RELATIONAL INTEGRITY FOR THE TAXONOMY (no database server needed)
  Base SAS datasets support primary keys, foreign keys, CHECK constraints and
  indexes.  Run AFTER 00a-00c.  To re-seed 00a-00c later, run the RESET block
  first (SAS will not replace a table another table's foreign key points at).
==========================================================================*/

/*---- RESET (uncomment before re-running 00a-00c) -------------------------
proc datasets lib=cmp nolist;
  modify kw_map;   ic delete _all_;
  modify tax_l3;   ic delete _all_;
  modify tax_l2;   ic delete _all_;
  modify tax_l1;   ic delete _all_;
  modify tax_trigger; ic delete _all_;
quit;
---------------------------------------------------------------------------*/

proc sql;
  /* primary keys: parents first */
  alter table cmp.tax_l1      add constraint pk_l1  primary key (l1_id);
  alter table cmp.tax_l2      add constraint pk_l2  primary key (l2_id);
  alter table cmp.tax_l3      add constraint pk_l3  primary key (l3_id);
  alter table cmp.tax_trigger add constraint pk_trg primary key (trg_id);
  alter table cmp.kw_map      add constraint pk_kw  primary key (kw_id);

  /* foreign keys: a parent cannot be deleted or re-keyed while children exist */
  alter table cmp.tax_l2 add constraint fk_l2_l1 foreign key (l1_id)
        references cmp.tax_l1 on delete restrict on update restrict;
  alter table cmp.tax_l3 add constraint fk_l3_l2 foreign key (l2_id)
        references cmp.tax_l2 on delete restrict on update restrict;
  alter table cmp.kw_map add constraint fk_kw_l3 foreign key (l3_id)
        references cmp.tax_l3 on delete restrict on update restrict;
  alter table cmp.kw_map add constraint fk_kw_trg foreign key (trg_id)
        references cmp.tax_trigger on delete restrict on update restrict;

  /* business rules */
  alter table cmp.kw_map add constraint ck_kw_type
        check (kw_type in ('ROOT', 'TRIGGER'));
  alter table cmp.kw_map add constraint ck_kw_parent   /* exactly one parent, matching the type */
        check ((kw_type = 'ROOT'    and l3_id  is not missing and trg_id is missing)
            or (kw_type = 'TRIGGER' and trg_id is not missing and l3_id  is missing));
  alter table cmp.kw_map add constraint ck_kw_weight check (kw_weight between 0 and 1);
quit;
/* NOTE: if your SAS release rejects missing values in the two nullable foreign
   keys on kw_map, drop fk_kw_l3/fk_kw_trg; ck_kw_parent plus the orphan check
   in 00b still guarantee referential integrity. */

/*---- Indexes for the lookups the pipeline repeats -----------------------*/
proc datasets lib=cmp nolist;
  modify kw_map;    index create kw_type;  index create l3_id;
  modify tax_l3;    index create l2_id;
  modify tax_l2;    index create l1_id;
quit;

/*---- One flat path view for reporting: L1 > L2 > L3 ----------------------*/
proc sql;
  create view cmp.v_taxonomy_path as
  select l3.l3_id, l3.l3_name, l2.l2_id, l2.l2_name, l1.l1_id, l1.l1_name,
         catx(' > ', l1.l1_name, l2.l2_name, l3.l3_name) as full_path length=160
    from cmp.tax_l3 l3
    inner join cmp.tax_l2 l2 on l3.l2_id = l2.l2_id
    inner join cmp.tax_l1 l1 on l2.l1_id = l1.l1_id
   where l3.active_flag = 1 and l2.active_flag = 1 and l1.active_flag = 1;
quit;

/*---- Change control: append-only audit of keyword edits ------------------*/
proc sql;
  create table cmp.kw_audit
   (audit_id num, kw_id num, action char(8), old_value char(60), new_value char(60),
    changed_by char(32), changed_dttm num format=datetime20., reason char(120));
quit;
