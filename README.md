# PGPYML - Deploy your Machine Learning Models on Postgres

This repository contains an Postgres extension that allows you to run your machine learning algorithms written in python and invoke them on Postgres. This way you can write your script in the way you are used to, and apply it right on your data. You can train and save your `sklearn` models and call then with the data stored on Postgres.

# EXTENSION UPDTAE
model_slice function is added to `pgpyml_try--0.3.1--0.3.2.sql`
**Contributions and suggestions are welcome**.

# Install
First, you need to
```shell
kim@kim:~/CP3106/pgpyml_try$ sudo make install
```

And create the extension on your database:
```sql
-- Create a new schema
CREATE SCHEMA IF NOT EXISTS pgpyml_try
-- Create the extension on pgpyml schema
CREATE EXTENSION pgpyml_try SCHEMA pgpyml_try CASCADE;
```

# Save your python sklearn model

After training your model, you can save it using `joblib`:
```python
from sklearn.tree import DecisionTreeClassifier
from joblib import dump, load
    
# some code to load your data...

model = DecisionTreeClassifier()

model.fit(X_train, y_train)
dump(model, './iris_decision_tree.joblib')
```

Once your model are ready, you can use it right on your data stored on Postgres.

# Using the model
You can use the `predict` function to apply the trained model on your stored data.
```sql
-- Notice that the features are passed as a nested array
SELECT * FROM pgpyml.predict('/var/lib/postgresql/iris_decision_tree.joblib', '{{5.2,3.5,1.5,0.2}}');
-- Output: {Iris-setosa} (or any other class your model predict)

-- You can pass many features at once
SELECT * FROM pgpyml.predict('/var/lib/postgresql/iris_decision_tree.joblib', '{{5.2,3.5,1.5,0.2}, {7.7,2.8,6.7,2.0}}');
-- Output: {Iris-setosa,Iris-virginica}

-- You can also use the ARRAY notation
SELECT * FROM pgpyml.predict('/var/lib/postgresql/iris_decision_tree.joblib', ARRAY[[5.2,3.5,1.5, 0.2], [7.7,2.8,6.7,2.0]]);
-- Output: {Iris-setosa,Iris-virginica}
```
The first argument is the path to your trained model, this path must be reachable by your Postgres server. The second argument is a list of features array, each element of the list will have an element on the output. The output are an text array with the predictions of your model.

You can also create a trigger to classify new data inserted on the table. You may use the function `classification_trigger` to help you create a trigger that use your trained model to classify your new data:
```sql
CREATE TABLE iris (
	id SERIAL PRIMARY KEY,
	sepal_length float,
	sepal_width float,
	petal_length float,
	petal_width float,
	class VARCHAR(20) -- column where the prediction will be saved
);

CREATE TRIGGER classify_iris
BEFORE INSERT OR UPDATE ON "iris"
FOR EACH ROW 
EXECUTE PROCEDURE pgpyml.classification_trigger(
	'/var/lib/postgresql/iris_decision_tree.joblib', -- Model path
	'class', -- Column name to save the result
	'sepal_length', -- Feature 1
	'sepal_width', -- Feature 2
	'petal_length', -- Feature 3
	'petal_width'-- Feature 4
);
```

The first argument of `classification_trigger` function is the path to your trained model, the second one is the column name where you want to save the prediction of your model (must exists in the same table where your trigger is acting), and any other parameter passed after the second argument will be used as a column name where the feature data are stored.

After creating the trigger you can insert new data on the table, and the result of the classification will be saved on the column specified in the second argument:

```sql
-- Notice that the class is not being inserted, but will be added by the trigger function
INSERT INTO iris (sepal_length, sepal_width, petal_length, petal_width) VALUES (5.2,3.5,1.5,0.2);

-- Check the last inserted row, it will have the column 'class' filled
SELECT * FROM iris WHERE id = (SELECT MAX(id) FROM iris);
```

Besides that you can also apply your model in the data that are already stored in your database. To do that you can use the `predict_table_row` function. This function expects as the first argument the model you want to use, the second argument is the name of the table where the data is stored, the third argument is an array with the name of the columns that will be used as features by your model, and finally the forth argument is the id of the row you want to classify: 

```sql
SELECT * FROM pgpyml.predict_table_row(
	'/var/lib/postgresql/iris_decision_tree.joblib', -- The trained model
	'iris', -- Table with the data
	'{"sepal_length", "sepal_width", "petal_length", "petal_width"}', -- The columns used as feature
	1 -- The ID of your data
);
```
