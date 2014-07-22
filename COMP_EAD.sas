
%MACRO COMP_EAD(comp_vars=gvkey fyearq fqtr conm datadate rdq 
				epsfxq epspxq
    			prccq ajexq 
    			spiq cshoq cshprq cshfdq 
    			saleq atq 
    			fyr datafqtr, 
			filter=not missing(saleq) or atq>0
			);

    %macro print(str);
    %put; %put &str.; %put;
    %mend;

    %print(### Merging comp.fundq with CCM linking table );
	proc sql;
		drop table comp_ead;
		drop view _comp_ead, _ead;

	    create view _comp_ead as
	    select a.gvkey, a.datadate, a.rdq,
	    	    b.lpermno as permno, b.lpermco as permco, 
	        /*Compustat variables*/
	        (a.cshoq*a.prccq) as mcap, a.*
	    from comp.fundq(where=(&filter.)) as a, 
	    	ccm.ccmxpf_linktable as b
	    where a.indfmt = 'INDL'
	    and a.datafmt = 'STD'
	    and a.popsrc = 'D'
	    and a.consol = 'C'
	    and substr(b.linktype,1,1)='L'
	    and b.linkprim in ('P','C')
	    and b.usedflag = 1
	    and (b.LINKDT <= a.datadate or b.LINKDT = .B) 
	    and (a.datadate <= b.LINKENDDT or b.LINKENDDT = .E)
	    and a.gvkey = b.gvkey
	    and a.rdq IS NOT NULL
	    ;

	    create view _ead as
	    select a.*, b.date as rdq_adj 
	    	format=yymmdd10. label='Adjusted Report Date of Quarterly Earnings'
	    from (select distinct rdq from _comp_ead) a
    	left join (select distinct date from crsp.dsi) b
    	on 5>=b.date-a.rdq>=0
    	group by rdq
    	having b.date-a.rdq=min(b.date-a.rdq)
    	;

    	create view _comp_ead_events
    		(keep=gvkey datadate rdq rdq_adj
	    	permno permco event_id mcap prccq &comp_vars.) as
    	select a.*, b.rdq_adj
    	from _comp_ead as a left join _ead as b
    	on a.rdq = b.rdq
    	order by a.gvkey, a.fyearq desc, a.fqtr desc
    	;
    quit;

    %print(### Checking for duplicates and outputting );
	proc sort data=_comp_ead_events 
		out=comp_ead_events nodupkey;
		by permno rdq_adj;
	run;

	data comp_ead_events;
		set comp_ead_events;
		event_id = _N_;
		label event_id="Unique Event Identifier";
	run;

    proc sql;
    	drop view _comp_ead_events, _comp_ead, _ead;
	quit;

	%print(### DONE );
%MEND COMP_EAD;