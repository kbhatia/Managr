$(function() {

	$.ajaxSetup({
		headers : {
			'X-CSRF-Token' : $('meta[name="csrf-token"]').attr('content')
		}
	});

	var PageManager = {
		init : function() {
			$('#page_name').on('change', {
				page_id: $('#page_name').val()
			}, this.getPagePosts);
			$('#page_name').on('change', {self:this}, this.getPageInsights);
			$('#page_name').on('change', {self:this}, this.getPageLikes);

			$('#post_type').on('change', this.showPostTypeField);
			$('#page_name').trigger('change');
			// $('#fb_page_posts').on('click','#load_more_button', 
						// {
							// fb_req_url:$('#load_more_button').data('paging_next'),
							// page_id: $('#page_name').val()
						// }, this.getPagePosts);
		},

		showPostTypeField : function() {
			switch($(this).val()) {
				case 'link':
					$('#fb-post-link').fadeIn();
					$('#fb-post-photo').fadeOut();
					break;
				case 'photo':
					$('#fb-post-link').fadeOut();
					$('#fb-post-photo').fadeIn();
					break;
				default:
					$('#fb-post-link').fadeOut();
					$('#fb-post-photo').fadeOut();
					break;
			}
		},

		getPagePosts : function(event) {
			var e = event;
			var obj = event.data.self;
			$.ajax({
				url : '/api/feed',
				type : 'GET',
				data : {
					page_id: $("#page_name").val()
				},
				dataType : 'json',
				beforeSend : function() {
					$('#ajax-loader-space').toggle();
				},
				success : function(response) {
					$('#ajax-loader-space').toggle();
					if (response.status.success) {
						var html = new EJS({
							url : '/ejs_templates/posts.ejs'
						}).render(response.data);
						$('#fb_page_posts').html(html);
						if(response.data.paging != undefined){
							$('#fb_page_posts').on('click','#load_more_button', function(){
								$.ajax({
									url: '/api/feed',
									type: 'GET',
									data: {
										fb_req_url:$('#load_more_button').data('paging_next')
									},
									beforeSend: function(){
										$('#load_more_button').text('Loading...');
									},
									success: function(response){
										$('#load_more_button').remove();
										var new_html = new EJS({
											url : '/ejs_templates/posts.ejs'
										}).render(response.data);
										$('#fb_page_posts').append(new_html);
										$('#load_more_button').text('Load more');
									}
								});
							});
						}
					} else {
						$('#fb_page_posts').html('<div class="alert alert-danger">' + response.status.msg + '</div>');
					}
				}
			});
		},
		
		getPageLikes: function(event) {
			$.ajax({
				url : '/api/pagelikes',
				type : 'GET',
				data : {
					page_id : $(this).val()
				},
				dataType : 'json',
				beforeSend : function() {
				},
				success : function(response) {
					if (response.status.success) {
						$('#page_likes').html('Page Likes:  ' + response.data.likes);

					}
				else {
						$('#page_likes').html('<div class="alert alert-danger">' + response.status.msg + '</div>');
					}
				}
			});
		},


		getPageInsights : function(event) {
			$.ajax({
				url : '/api/insights',
				type : 'GET',
				data : {
					page_id : $(this).val()
				},
				dataType : 'json',
				beforeSend : function() {
				},
				success : function(response) {
					if (response.status.success) {
						var html = new EJS({
							url : '/ejs_templates/insights.ejs'
						}).render(response.data);
						var chartData = {
							'labels' : ['Daily', 'Weekly'],
							datasets : [{
								fillColor : "rgba(220,220,220,0.5)",
								strokeColor : "rgba(220,220,220,1)",
								pointColor : "rgba(220,220,220,1)",
								pointStrokeColor : "#fff",
								data : [
									response.data.data[0].values[0].value, 
									response.data.data[0].values[1].value,
									response.data.data[0].values[2].value,
								]
							}, {
								fillColor : "rgba(151,187,205,0.5)",
								strokeColor : "rgba(151,187,205,1)",
								pointColor : "rgba(151,187,205,1)",
								pointStrokeColor : "#fff",
								data : [
									response.data.data[1].values[0].value, 
									response.data.data[1].values[1].value,
									response.data.data[1].values[2].value,
								]
							}]
						};
						console.log(chartData);
						event.data.self.drawChart(chartData);
						//$('#insight_data').html(html);
					} else {
						$('#insight_data').html('<div class="alert alert-danger">' + response.status.message + '</div>');
					}
				}
			});
		},

		drawChart : function(chartData) {
			var ctx = $("#myChart").get(0).getContext("2d");
			var myNewChart = new Chart(ctx);
			myNewChart.Line(chartData,{});
		},

		loadMorePosts : function() {

		}
	};

	PageManager.init();

});
