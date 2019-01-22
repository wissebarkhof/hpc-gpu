/* datatools.h - support functions for the matrix examples
 *
 * Author:  Bernd Dammann, DTU Compute
 * Version: $Revision: 1.1 $ $Date: 2015/11/10 11:01:43 $
 */

void init_matrix(int m,       /* number of rows               */
                 int n,       /* number of columns            */
                 double *A,   /* two-dim array of size m-by-n */
                 double value /* two-dim array of size m-by-n */
);

void init_M(int m, int n, double **A);

void print_matrix (int m,
		   int n,
		   double *A);

void init_M (int m, int n, double **A);

void init_vector (int m, double *V);


int check_results(char *comment, /* comment string 		 */
                  int m,         /* number of rows               */
                  int n,         /* number of columns            */
                  double **a     /* vector of length m           */
);

double **malloc_2d(int m, /* number of rows               */
                   int n  /* number of columns            */
);

void free_2d(double **A); /* free data allocated by malloc_2d */
